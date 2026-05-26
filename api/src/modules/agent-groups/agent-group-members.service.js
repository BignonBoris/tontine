const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const {
  findOwnedGroup,
  serializeGroup,
  syncGroupMembershipState,
} = require('./agent-groups.service');
const {
  getClientGroupCapacityProfile,
} = require('./agent-group-capacity.service');

function serializeMember(member, extras = {}) {
  return {
    id: member.id,
    groupId: member.groupId,
    clientUserId: member.clientUserId,
    status: member.status,
    joinedAt: member.joinedAt,
    turnPosition: member.turnPosition,
    removedAt: member.removedAt,
    removalReason: member.removalReason,
    client: member.client
      ? {
          id: member.client.id,
          displayName: member.client.displayName,
          phoneNumber: displayPhone(member.client.phoneNumber),
          address: member.client.address,
          memberSince: member.client.memberSince,
        }
      : null,
    ...extras,
  };
}

async function ensureManageableGroup(agentProfileId, groupId, transaction = null) {
  const group = await findOwnedGroup(agentProfileId, groupId, transaction);
  if (group.startedAt) {
    throw new AppError(
      'Les participants ne peuvent plus etre modifies apres le demarrage du groupe.',
      422,
    );
  }
  return group;
}

async function syncGroupMemberCount(group, transaction) {
  const activeCount = await models.AgentGroupMember.count({
    where: { groupId: group.id, status: 'active' },
    transaction,
  });

  await group.update({ memberCount: activeCount }, { transaction });
  await syncGroupMembershipState(group, transaction);
  return group;
}

async function computeMemberCapacitySummary(group, member, transaction) {
  return getClientGroupCapacityProfile(member.clientUserId, {
    groupId: group.id,
    participantCount: group.participantCount,
    contributionAmount: group.contributionAmount,
    transaction,
  });
}

async function recalculateGroupTurnOrder(group, transaction, manualOrderedMemberIds = null) {
  if (!group || group.startedAt) {
    return;
  }

  const activeMembers = await models.AgentGroupMember.findAll({
    where: { groupId: group.id, status: 'active' },
    include: [{ model: models.User, as: 'client', required: false }],
    order: [
      ['joinedAt', 'ASC'],
      ['createdAt', 'ASC'],
    ],
    transaction,
    lock: transaction.LOCK.UPDATE,
  });

  if (activeMembers.length === 0) {
    return;
  }

  const orderedMembers = manualOrderedMemberIds
    ? manualOrderedMemberIds.map((memberId) =>
        activeMembers.find((member) => member.id === memberId),
      )
    : activeMembers;

  const minimumTurns = new Map();
  for (const member of activeMembers) {
    const capacity = await computeMemberCapacitySummary(group, member, transaction);
    minimumTurns.set(member.id, capacity.minimumEligibleTurn);
  }

  const availableTurns = Array.from(
    { length: Number(group.participantCount || 0) },
    (_, index) => index + 1,
  );
  const assignments = new Map();

  for (const member of orderedMembers) {
    if (!member) {
      continue;
    }
    const minimumTurn = minimumTurns.get(member.id) || group.participantCount + 1;
    const turnIndex = availableTurns.findIndex((turn) => turn >= minimumTurn);
    if (turnIndex === -1) {
      assignments.set(member.id, null);
      continue;
    }
    assignments.set(member.id, availableTurns[turnIndex]);
    availableTurns.splice(turnIndex, 1);
  }

  for (const member of activeMembers) {
    const nextTurnPosition = assignments.get(member.id) || null;
    if (member.turnPosition !== nextTurnPosition) {
      await member.update({ turnPosition: nextTurnPosition }, { transaction });
    }
  }
}

async function listGroupMembers(agentProfileId, groupId, filters = {}) {
  const group = await findOwnedGroup(agentProfileId, groupId);

  const status = String(filters.status || 'all').trim();
  const search = String(filters.q || '').trim();
  const where = { groupId };

  if (
    ['requested', 'invited', 'active', 'declined', 'rejected', 'removed'].includes(
      status,
    )
  ) {
    where.status = status;
  }

  const include = [
    {
      model: models.User,
      as: 'client',
      required: true,
      where: search
        ? {
            [Op.or]: [
              { displayName: { [Op.like]: `%${search}%` } },
              { phoneNumber: { [Op.like]: `%${search.replace(/\D/g, '')}%` } },
            ],
          }
        : undefined,
    },
  ];

  const members = await models.AgentGroupMember.findAll({
    where,
    include,
    order: [['createdAt', 'ASC']],
  });

  const statusOrder = {
    active: 1,
    requested: 2,
    invited: 3,
    declined: 4,
    rejected: 5,
    removed: 6,
  };

  const serializedMembers = [];
  for (const member of members
    .sort((left, right) => {
      const leftTurn = Number(left.turnPosition || 0);
      const rightTurn = Number(right.turnPosition || 0);
      if (leftTurn && rightTurn && leftTurn !== rightTurn) {
        return leftTurn - rightTurn;
      }
      if (leftTurn && !rightTurn) {
        return -1;
      }
      if (!leftTurn && rightTurn) {
        return 1;
      }
      const leftRank = statusOrder[left.status] || 99;
      const rightRank = statusOrder[right.status] || 99;
      if (leftRank !== rightRank) {
        return leftRank - rightRank;
      }
      const leftTime = new Date(left.joinedAt || left.createdAt || 0).getTime();
      const rightTime = new Date(right.joinedAt || right.createdAt || 0).getTime();
      return leftTime - rightTime;
    })) {
    let capacitySummary = null;
    if (member.status === 'active') {
      capacitySummary = await computeMemberCapacitySummary(group, member, null);
    }
    serializedMembers.push(
      serializeMember(member, {
        minimumEligibleTurn: capacitySummary?.minimumEligibleTurn || null,
        estimatedCapacity: capacitySummary?.estimatedCapacity || null,
        activeGroupDebt: capacitySummary?.activeGroupDebt || null,
        netEstimatedCapacity: capacitySummary?.netEstimatedCapacity || null,
      }),
    );
  }

  return serializedMembers;
}

async function listGroupMemberCandidates(agentProfileId, groupId, query) {
  await findOwnedGroup(agentProfileId, groupId);

  const search = String(query || '').trim();
  const activeMemberships = await models.AgentGroupMember.findAll({
    where: { groupId, status: { [Op.in]: ['active', 'invited', 'requested'] } },
    attributes: ['clientUserId'],
  });
  const excludedIds = activeMemberships.map((item) => item.clientUserId);

  const where = {
    isActive: true,
    accountType: { [Op.ne]: 'Agent' },
    '$agentProfile.id$': null,
    ...(excludedIds.length > 0 ? { id: { [Op.notIn]: excludedIds } } : {}),
  };

  if (search) {
    const digits = search.replace(/\D/g, '');
    where[Op.or] = [
      { displayName: { [Op.like]: `%${search}%` } },
      { phoneNumber: { [Op.like]: `%${digits}%` } },
      { address: { [Op.like]: `%${search}%` } },
    ];
  }

  const clients = await models.User.findAll({
    where,
    include: [
      { model: models.AgentProfile, as: 'agentProfile', required: false },
    ],
    order: [['displayName', 'ASC']],
    limit: 50,
  });

  const group = await findOwnedGroup(agentProfileId, groupId);

  const candidates = [];
  for (const client of clients) {
    const capacitySummary = await getClientGroupCapacityProfile(client.id, {
      groupId: group.id,
      participantCount: group.participantCount,
      contributionAmount: group.contributionAmount,
    });

    candidates.push({
      id: client.id,
      displayName: client.displayName,
      phoneNumber: displayPhone(client.phoneNumber),
      address: client.address,
      memberSince: client.memberSince,
      minimumEligibleTurn: capacitySummary.minimumEligibleTurn,
      estimatedCapacity: capacitySummary.estimatedCapacity,
      activeGroupDebt: capacitySummary.activeGroupDebt,
      netEstimatedCapacity: capacitySummary.netEstimatedCapacity,
      canBeRanked: capacitySummary.canBeRanked,
    });
  }

  return candidates;
}

async function addGroupMember(agentProfile, groupId, payload, requestContext = {}) {
  const clientUserId = String(payload?.clientUserId || '').trim();
  if (!clientUserId) {
    throw new AppError('Le client a inviter est requis.', 422);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const group = await ensureManageableGroup(agentProfile.id, groupId, transaction);

    const client = await models.User.findOne({
      where: {
        id: clientUserId,
        isActive: true,
        accountType: { [Op.ne]: 'Agent' },
      },
      include: [
        { model: models.AgentProfile, as: 'agentProfile', required: false },
      ],
      transaction,
    });

    if (!client || client.agentProfile) {
      throw new AppError('Client introuvable ou invalide pour ce groupe.', 404);
    }

    const existingMember = await models.AgentGroupMember.findOne({
      where: { groupId: group.id, clientUserId: client.id },
      include: [{ model: models.User, as: 'client', required: false }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    let member;
    if (existingMember && existingMember.status === 'active') {
      throw new AppError('Ce client est deja actif dans ce groupe.', 409);
    }
    if (existingMember && existingMember.status === 'invited') {
      throw new AppError('Une invitation est deja en attente pour ce client.', 409);
    }
    if (existingMember && existingMember.status === 'requested') {
      throw new AppError(
        'Ce client a deja une demande d adhesion en attente de validation.',
        409,
      );
    }

    if (existingMember) {
      member = await existingMember.update(
        {
          status: 'invited',
          joinedAt: new Date(),
          removedAt: null,
          removalReason: 'Invitation relancee par l agent',
          removedByUserId: null,
          addedByUserId: agentProfile.userId,
        },
        { transaction },
      );
    } else {
      member = await models.AgentGroupMember.create(
        {
          groupId: group.id,
          clientUserId: client.id,
          status: 'invited',
          joinedAt: new Date(),
          addedByUserId: agentProfile.userId,
        },
        { transaction },
      );
    }

    await syncGroupMemberCount(group, transaction);
    await recalculateGroupTurnOrder(group, transaction);
    const refreshedMember = await models.AgentGroupMember.findByPk(member.id, {
      include: [{ model: models.User, as: 'client', required: false }],
      transaction,
    });

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_member_invited',
      entityType: 'agentGroupMember',
      entityId: member.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        clientUserId: client.id,
      },
      transaction,
    });

    return { group, member: refreshedMember };
  });

  return {
    group: serializeGroup(result.group),
      member: serializeMember(result.member),
  };
}

async function removeGroupMember(
  agentProfile,
  groupId,
  memberId,
  payload,
  requestContext = {},
) {
  const reason = String(payload?.reason || '').trim() || 'Retire du groupe avant demarrage';

  const result = await sequelize.transaction(async (transaction) => {
    const group = await ensureManageableGroup(agentProfile.id, groupId, transaction);

    const member = await models.AgentGroupMember.findOne({
      where: { id: memberId, groupId: group.id },
      include: [{ model: models.User, as: 'client', required: false }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!member) {
      throw new AppError('Participant introuvable dans ce groupe.', 404);
    }
    if (!['active', 'invited'].includes(member.status)) {
      throw new AppError('Ce participant n est plus modifiable dans ce groupe.', 422);
    }

    await member.update(
      {
        status: 'removed',
        removedAt: new Date(),
        removalReason: reason,
        removedByUserId: agentProfile.userId,
      },
      { transaction },
    );

    await syncGroupMemberCount(group, transaction);
    await recalculateGroupTurnOrder(group, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_member_removed',
      entityType: 'agentGroupMember',
      entityId: member.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        clientUserId: member.clientUserId,
        reason,
      },
      transaction,
    });

    return { group, member };
  });

  return {
    group: serializeGroup(result.group),
    member: serializeMember(result.member),
  };
}

async function approveGroupMemberRequest(
  agentProfile,
  groupId,
  memberId,
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const group = await ensureManageableGroup(agentProfile.id, groupId, transaction);

    const member = await models.AgentGroupMember.findOne({
      where: { id: memberId, groupId: group.id },
      include: [{ model: models.User, as: 'client', required: false }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!member) {
      throw new AppError('Demande d adhesion introuvable dans ce groupe.', 404);
    }
    if (member.status !== 'requested') {
      throw new AppError(
        'Seules les demandes en attente peuvent etre validees.',
        422,
      );
    }
    if (Number(group.memberCount) >= Number(group.participantCount)) {
      throw new AppError(
        'Le groupe a deja atteint son nombre cible. Reduisez ou ajustez le groupe avant toute nouvelle validation.',
        422,
      );
    }

    await member.update(
      {
        status: 'active',
        joinedAt: new Date(),
        removedAt: null,
        removalReason: null,
        removedByUserId: null,
        addedByUserId: agentProfile.userId,
      },
      { transaction },
    );

    await syncGroupMemberCount(group, transaction);
    await recalculateGroupTurnOrder(group, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_join_request_approved',
      entityType: 'agentGroupMember',
      entityId: member.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        clientUserId: member.clientUserId,
      },
      transaction,
    });

    return { group, member };
  });

  return {
    group: serializeGroup(result.group),
    member: serializeMember(result.member),
  };
}

async function rejectGroupMemberRequest(
  agentProfile,
  groupId,
  memberId,
  payload,
  requestContext = {},
) {
  const reason = String(payload?.reason || '').trim() || 'Demande refusee par l agent';

  const result = await sequelize.transaction(async (transaction) => {
    const group = await ensureManageableGroup(agentProfile.id, groupId, transaction);

    const member = await models.AgentGroupMember.findOne({
      where: { id: memberId, groupId: group.id },
      include: [{ model: models.User, as: 'client', required: false }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!member) {
      throw new AppError('Demande d adhesion introuvable dans ce groupe.', 404);
    }
    if (member.status !== 'requested') {
      throw new AppError(
        'Seules les demandes en attente peuvent etre refusees.',
        422,
      );
    }

    await member.update(
      {
        status: 'rejected',
        removedAt: new Date(),
        removalReason: reason,
        removedByUserId: agentProfile.userId,
      },
      { transaction },
    );

    await syncGroupMemberCount(group, transaction);
    await recalculateGroupTurnOrder(group, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_join_request_rejected',
      entityType: 'agentGroupMember',
      entityId: member.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        clientUserId: member.clientUserId,
        reason,
      },
      transaction,
    });

    return { group, member };
  });

  return {
    group: serializeGroup(result.group),
    member: serializeMember(result.member),
  };
}

async function saveGroupTurnOrder(
  agentProfile,
  groupId,
  payload,
  requestContext = {},
) {
  const orderedMemberIds = Array.isArray(payload?.orderedMemberIds)
    ? payload.orderedMemberIds.map((value) => String(value || '').trim()).filter(Boolean)
    : [];

  const result = await sequelize.transaction(async (transaction) => {
    const group = await ensureManageableGroup(agentProfile.id, groupId, transaction);

    const activeMembers = await models.AgentGroupMember.findAll({
      where: { groupId: group.id, status: 'active' },
      order: [['joinedAt', 'ASC'], ['createdAt', 'ASC']],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (orderedMemberIds.length !== activeMembers.length) {
      throw new AppError(
        'La liste des tours doit contenir exactement tous les membres actifs du groupe.',
        422,
      );
    }

    const activeMemberIds = new Set(activeMembers.map((member) => member.id));
    for (const memberId of orderedMemberIds) {
      if (!activeMemberIds.has(memberId)) {
        throw new AppError(
          'Un membre inactif ou inconnu a ete inclus dans l ordre des tours.',
          422,
        );
      }
    }

    await recalculateGroupTurnOrder(group, transaction, orderedMemberIds);

    const refreshedMembers = await models.AgentGroupMember.findAll({
      where: { groupId: group.id, status: 'active' },
      include: [{ model: models.User, as: 'client', required: false }],
      order: [['turnPosition', 'ASC']],
      transaction,
    });

    for (const member of refreshedMembers) {
      const capacitySummary = await computeMemberCapacitySummary(
        group,
        member,
        transaction,
      );
      if (
        !member.turnPosition ||
        member.turnPosition < Number(capacitySummary.minimumEligibleTurn || 0)
      ) {
        throw new AppError(
          'Un membre a ete place avant son rang minimum autorise.',
          422,
        );
      }
    }

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_turn_order_updated',
      entityType: 'agentGroup',
      entityId: group.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: group.reference,
        orderedMemberIds,
      },
      transaction,
    });

    return { group, members: refreshedMembers };
  });

  const members = [];
  for (const member of result.members) {
    const capacitySummary = await computeMemberCapacitySummary(result.group, member, null);
    members.push(
      serializeMember(member, {
        minimumEligibleTurn: capacitySummary.minimumEligibleTurn,
        estimatedCapacity: capacitySummary.estimatedCapacity,
        activeGroupDebt: capacitySummary.activeGroupDebt,
        netEstimatedCapacity: capacitySummary.netEstimatedCapacity,
      }),
    );
  }

  return {
    group: serializeGroup(result.group),
    members,
  };
}

module.exports = {
  listGroupMembers,
  listGroupMemberCandidates,
  addGroupMember,
  removeGroupMember,
  approveGroupMemberRequest,
  rejectGroupMemberRequest,
  saveGroupTurnOrder,
  recalculateGroupTurnOrder,
};
