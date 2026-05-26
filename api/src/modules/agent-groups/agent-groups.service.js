const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { AGENT_GROUP_TURN_UNITS } = require('../../common/constants/enums');
const {
  getClientGroupCapacityProfile,
} = require('./agent-group-capacity.service');

function normalizeGroupName(value) {
  return String(value || '').trim().replace(/\s+/g, ' ');
}

function normalizeComparableGroupName(value) {
  return normalizeGroupName(value).toLowerCase();
}

function normalizeDescription(value) {
  const normalized = String(value || '').trim().replace(/\s+/g, ' ');
  return normalized || null;
}

function generateGroupReference() {
  return `GRP-${Date.now()}-${Math.floor(Math.random() * 9000)
    .toString()
    .padStart(4, '0')}`;
}

function parsePlannedStartDate(value) {
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}

function computeLaunchStatus({ status, memberCount, participantCount, startedAt, launchCancelledAt }) {
  if (startedAt) {
    return 'started';
  }
  if (launchCancelledAt) {
    return 'launch_cancelled';
  }
  if (status !== 'active') {
    return 'collecting';
  }
  if (Number(memberCount) === Number(participantCount)) {
    return 'ready';
  }
  return 'collecting';
}

function serializeGroup(group) {
  if (!group) {
    return null;
  }

  return {
    id: group.id,
    reference: group.reference,
    name: group.name,
    description: group.description,
    participantCount: Number(group.participantCount),
    memberCount: Number(group.memberCount),
    turnIntervalValue: Number(group.turnIntervalValue),
    turnIntervalUnit: group.turnIntervalUnit,
    contributionAmount: Number(group.contributionAmount),
    plannedStartDate: group.plannedStartDate,
    launchStatus: group.launchStatus,
    startedAt: group.startedAt,
    launchCancelledAt: group.launchCancelledAt,
    launchCancellationReason: group.launchCancellationReason,
    status: group.status,
    agentProfileId: group.agentProfileId,
    createdAt: group.createdAt,
    updatedAt: group.updatedAt,
  };
}

async function serializeGroupWithTurnSummary(group, transaction = null) {
  const serialized = serializeGroup(group);
  if (!group) {
    return null;
  }

  const activeMembers = await models.AgentGroupMember.findAll({
    where: { groupId: group.id, status: 'active' },
    order: [['turnPosition', 'ASC'], ['joinedAt', 'ASC'], ['createdAt', 'ASC']],
    transaction,
  });

  const turnMembers = [];
  let hasUnrankableMember = false;
  for (const member of activeMembers) {
    const capacitySummary = await getClientGroupCapacityProfile(member.clientUserId, {
      groupId: group.id,
      participantCount: group.participantCount,
      contributionAmount: group.contributionAmount,
      transaction,
    });

    if (!capacitySummary.canBeRanked) {
      hasUnrankableMember = true;
    }

    turnMembers.push({
      memberId: member.id,
      clientUserId: member.clientUserId,
      turnPosition: member.turnPosition,
      minimumEligibleTurn: capacitySummary.minimumEligibleTurn,
    });
  }

  return {
    ...serialized,
    turnOrderLocked: Boolean(group.startedAt),
    hasUnrankableMember,
    turnMembers,
  };
}

function validateGroupPayload(payload, { partial = false } = {}) {
  const hasName = Object.prototype.hasOwnProperty.call(payload || {}, 'name');
  const hasDescription = Object.prototype.hasOwnProperty.call(
    payload || {},
    'description',
  );
  const hasParticipantCount = Object.prototype.hasOwnProperty.call(
    payload || {},
    'participantCount',
  );
  const hasTurnIntervalValue = Object.prototype.hasOwnProperty.call(
    payload || {},
    'turnIntervalValue',
  );
  const hasTurnIntervalUnit = Object.prototype.hasOwnProperty.call(
    payload || {},
    'turnIntervalUnit',
  );
  const hasPlannedStartDate = Object.prototype.hasOwnProperty.call(
    payload || {},
    'plannedStartDate',
  );
  const hasMemberCount = Object.prototype.hasOwnProperty.call(
    payload || {},
    'memberCount',
  );
  const hasContributionAmount = Object.prototype.hasOwnProperty.call(
    payload || {},
    'contributionAmount',
  );

  const name = hasName ? normalizeGroupName(payload.name) : undefined;
  const description = hasDescription
    ? normalizeDescription(payload.description)
    : undefined;
  const participantCount = hasParticipantCount
    ? Number(payload.participantCount)
    : undefined;
  const turnIntervalValue = hasTurnIntervalValue
    ? Number(payload.turnIntervalValue)
    : undefined;
  const turnIntervalUnit = hasTurnIntervalUnit
    ? String(payload.turnIntervalUnit || '').trim().toLowerCase()
    : undefined;
  const plannedStartDate = hasPlannedStartDate
    ? parsePlannedStartDate(payload.plannedStartDate)
    : undefined;
  const memberCount = hasMemberCount ? Number(payload.memberCount) : undefined;
  const contributionAmount = hasContributionAmount
    ? Number(payload.contributionAmount)
    : undefined;

  if (!partial || hasName) {
    if (!name) {
      throw new AppError('Le nom du groupe est requis.', 422);
    }
    if (name.length < 3 || name.length > 160) {
      throw new AppError(
        'Le nom du groupe doit contenir entre 3 et 160 caracteres.',
        422,
      );
    }
  }

  if (hasDescription && description && description.length > 255) {
    throw new AppError(
      'La description du groupe ne doit pas depasser 255 caracteres.',
      422,
    );
  }

  if (!partial || hasParticipantCount) {
    if (!Number.isInteger(participantCount) || participantCount < 2) {
      throw new AppError(
        'Le nombre de participants doit etre un entier superieur ou egal a 2.',
        422,
      );
    }
  }

  if (!partial || hasTurnIntervalValue) {
    if (!Number.isInteger(turnIntervalValue) || turnIntervalValue < 1) {
      throw new AppError(
        'Le delai d un tour doit etre un entier superieur ou egal a 1.',
        422,
      );
    }
  }

  if (!partial || hasTurnIntervalUnit) {
    if (!AGENT_GROUP_TURN_UNITS.includes(turnIntervalUnit)) {
      throw new AppError(
        'L unite du delai doit etre day, week ou month.',
        422,
      );
    }
  }

  if (!partial || hasContributionAmount) {
    if (
      !Number.isFinite(contributionAmount) ||
      contributionAmount <= 0 ||
      contributionAmount % 500 !== 0
    ) {
      throw new AppError(
        'Le montant par personne doit etre un multiple positif de 500.',
        422,
      );
    }
  }

  if (!partial || hasPlannedStartDate) {
    if (!plannedStartDate) {
      throw new AppError('La date de debut envisagee est invalide.', 422);
    }
  }

  if (!partial || hasMemberCount) {
    if (!Number.isInteger(memberCount) || memberCount < 0) {
      throw new AppError(
        'Le nombre de participants actuels doit etre un entier positif ou nul.',
        422,
      );
    }
  }

  return {
    ...(hasName ? { name, normalizedName: normalizeComparableGroupName(name) } : {}),
    ...(hasDescription ? { description } : {}),
    ...(hasParticipantCount ? { participantCount } : {}),
    ...(hasTurnIntervalValue ? { turnIntervalValue } : {}),
    ...(hasTurnIntervalUnit ? { turnIntervalUnit } : {}),
    ...(hasPlannedStartDate ? { plannedStartDate } : {}),
    ...(hasMemberCount ? { memberCount } : {}),
    ...(hasContributionAmount ? { contributionAmount } : {}),
  };
}

async function syncLaunchStatus(group, transaction) {
  const nextLaunchStatus = computeLaunchStatus(group);
  if (group.launchStatus === nextLaunchStatus) {
    return group;
  }
  await group.update({ launchStatus: nextLaunchStatus }, { transaction });
  return group;
}

async function syncGroupMembershipState(group, transaction) {
  return syncLaunchStatus(group, transaction);
}

async function ensureUniqueGroupName(
  agentProfileId,
  normalizedName,
  excludedGroupId = null,
  transaction = null,
) {
  if (!normalizedName) {
    return;
  }

  const existingGroup = await models.AgentGroup.findOne({
    where: {
      agentProfileId,
      normalizedName,
      ...(excludedGroupId ? { id: { [Op.ne]: excludedGroupId } } : {}),
    },
    transaction,
  });

  if (existingGroup) {
    throw new AppError('Un groupe existe deja avec ce nom.', 409);
  }
}

async function findOwnedGroup(agentProfileId, groupId, transaction = null) {
  const group = await models.AgentGroup.findOne({
    where: { id: groupId, agentProfileId },
    transaction,
  });

  if (!group) {
    throw new AppError('Groupe introuvable dans votre portefeuille.', 404);
  }

  return group;
}

async function listGroups(agentProfileId, filters = {}) {
  const search = normalizeGroupName(filters.q);
  const status = String(filters.status || 'all').trim();

  const where = { agentProfileId };
  if (status === 'active' || status === 'suspended') {
    where.status = status;
  }

  if (search) {
    where[Op.or] = [
      { name: { [Op.like]: `%${search}%` } },
      { reference: { [Op.like]: `%${search}%` } },
    ];
  }

  const groups = await models.AgentGroup.findAll({
    where,
    order: [
      ['plannedStartDate', 'ASC'],
      ['status', 'ASC'],
      ['createdAt', 'DESC'],
    ],
  });

  return groups.map((group) => serializeGroup(group));
}

async function getGroupDetail(agentProfileId, groupId) {
  const group = await findOwnedGroup(agentProfileId, groupId);
  return serializeGroupWithTurnSummary(group);
}

async function createGroup(agentProfile, payload, requestContext = {}) {
  const normalizedPayload = validateGroupPayload(payload);

  const group = await sequelize.transaction(async (transaction) => {
    await ensureUniqueGroupName(
      agentProfile.id,
      normalizedPayload.normalizedName,
      null,
      transaction,
    );

    const createdGroup = await models.AgentGroup.create(
      {
        reference: generateGroupReference(),
        agentProfileId: agentProfile.id,
        name: normalizedPayload.name,
        normalizedName: normalizedPayload.normalizedName,
        description: normalizedPayload.description || null,
        participantCount: normalizedPayload.participantCount,
        memberCount: 0,
        turnIntervalValue: normalizedPayload.turnIntervalValue,
        turnIntervalUnit: normalizedPayload.turnIntervalUnit,
        contributionAmount: normalizedPayload.contributionAmount,
        plannedStartDate: normalizedPayload.plannedStartDate,
        launchStatus: computeLaunchStatus({
          status: 'active',
          memberCount: 0,
          participantCount: normalizedPayload.participantCount,
          startedAt: null,
          launchCancelledAt: null,
        }),
        status: 'active',
      },
      { transaction },
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_created',
      entityType: 'agentGroup',
      entityId: createdGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: createdGroup.reference,
        status: createdGroup.status,
        name: createdGroup.name,
        participantCount: createdGroup.participantCount,
        memberCount: 0,
        turnIntervalValue: createdGroup.turnIntervalValue,
        turnIntervalUnit: createdGroup.turnIntervalUnit,
        contributionAmount: Number(createdGroup.contributionAmount),
        plannedStartDate: createdGroup.plannedStartDate,
      },
      transaction,
    });

    return createdGroup;
  });

  return serializeGroup(group);
}

async function updateGroup(agentProfile, groupId, payload, requestContext = {}) {
  const membersService = require('./agent-group-members.service');
  const normalizedPayload = validateGroupPayload(payload, { partial: true });
  delete normalizedPayload.memberCount;
  if (Object.keys(normalizedPayload).length === 0) {
    throw new AppError('Aucune modification a appliquer sur le groupe.', 422);
  }

  const group = await sequelize.transaction(async (transaction) => {
    const existingGroup = await findOwnedGroup(agentProfile.id, groupId, transaction);

    if (existingGroup.startedAt) {
      throw new AppError(
        'Un groupe deja demarre ne peut plus etre modifie.',
        422,
      );
    }

    if (normalizedPayload.normalizedName) {
      await ensureUniqueGroupName(
        agentProfile.id,
        normalizedPayload.normalizedName,
        existingGroup.id,
        transaction,
      );
    }

    if (
      Object.prototype.hasOwnProperty.call(normalizedPayload, 'participantCount') &&
      Number(normalizedPayload.participantCount) < Number(existingGroup.memberCount)
    ) {
      throw new AppError(
        'Le nombre cible ne peut pas etre inferieur au nombre actuel de membres actifs.',
        422,
      );
    }

    await existingGroup.update(
      {
        ...normalizedPayload,
        launchCancelledAt:
          normalizedPayload.plannedStartDate
            ? null
            : existingGroup.launchCancelledAt,
        launchCancellationReason:
          normalizedPayload.plannedStartDate
            ? null
            : existingGroup.launchCancellationReason,
      },
      { transaction },
    );
    if (
      Object.prototype.hasOwnProperty.call(normalizedPayload, 'participantCount') ||
      Object.prototype.hasOwnProperty.call(normalizedPayload, 'contributionAmount')
    ) {
      await membersService.recalculateGroupTurnOrder(existingGroup, transaction);
    }
    await syncLaunchStatus(existingGroup, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_updated',
      entityType: 'agentGroup',
      entityId: existingGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: existingGroup.reference,
        changes: {
          ...(normalizedPayload.name ? { name: existingGroup.name } : {}),
          ...(Object.prototype.hasOwnProperty.call(normalizedPayload, 'description')
            ? { description: existingGroup.description }
            : {}),
          ...(Object.prototype.hasOwnProperty.call(normalizedPayload, 'participantCount')
            ? { participantCount: existingGroup.participantCount }
            : {}),
          ...(Object.prototype.hasOwnProperty.call(normalizedPayload, 'turnIntervalValue')
            ? { turnIntervalValue: existingGroup.turnIntervalValue }
            : {}),
          ...(Object.prototype.hasOwnProperty.call(normalizedPayload, 'turnIntervalUnit')
            ? { turnIntervalUnit: existingGroup.turnIntervalUnit }
            : {}),
          ...(Object.prototype.hasOwnProperty.call(normalizedPayload, 'plannedStartDate')
            ? { plannedStartDate: existingGroup.plannedStartDate }
            : {}),
          ...(Object.prototype.hasOwnProperty.call(normalizedPayload, 'contributionAmount')
            ? { contributionAmount: Number(existingGroup.contributionAmount) }
            : {}),
        },
      },
      transaction,
    });

    return existingGroup;
  });

  return serializeGroupWithTurnSummary(group);
}

async function changeGroupStatus(
  agentProfile,
  groupId,
  nextStatus,
  requestContext = {},
) {
  if (!['active', 'suspended'].includes(nextStatus)) {
    throw new AppError('Statut groupe invalide.', 422);
  }

  const group = await sequelize.transaction(async (transaction) => {
    const existingGroup = await findOwnedGroup(agentProfile.id, groupId, transaction);
    if (existingGroup.status === nextStatus) {
      return existingGroup;
    }

    await existingGroup.update({ status: nextStatus }, { transaction });
    await syncLaunchStatus(existingGroup, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action:
        nextStatus === 'active'
          ? 'agent.group_activated'
          : 'agent.group_suspended',
      entityType: 'agentGroup',
      entityId: existingGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: existingGroup.reference,
        status: nextStatus,
      },
      transaction,
    });

    return existingGroup;
  });

  return serializeGroup(group);
}

async function launchGroup(agentProfile, groupId, requestContext = {}) {
  const membersService = require('./agent-group-members.service');
  const {
    ensureContributionScheduleForGroup,
  } = require('./agent-group-contributions.service');
  const group = await sequelize.transaction(async (transaction) => {
    const existingGroup = await findOwnedGroup(agentProfile.id, groupId, transaction);

    if (existingGroup.status !== 'active') {
      throw new AppError('Seul un groupe actif peut etre demarre.', 422);
    }
    if (existingGroup.startedAt) {
      throw new AppError('Cette tontine de groupe a deja ete demarree.', 409);
    }
    if (existingGroup.launchCancelledAt) {
      throw new AppError('Le lancement de ce groupe a ete annule.', 422);
    }
    if (Number(existingGroup.memberCount) !== Number(existingGroup.participantCount)) {
      throw new AppError(
        'Le lancement est autorise uniquement si le nombre de membres actifs est exactement egal au nombre cible de participants.',
        422,
      );
    }

    await membersService.recalculateGroupTurnOrder(existingGroup, transaction);

    const activeMembers = await models.AgentGroupMember.findAll({
      where: { groupId: existingGroup.id, status: 'active' },
      transaction,
    });

    for (const member of activeMembers) {
      const capacitySummary = await getClientGroupCapacityProfile(member.clientUserId, {
        groupId: existingGroup.id,
        participantCount: existingGroup.participantCount,
        contributionAmount: existingGroup.contributionAmount,
        transaction,
      });

      if (
        !member.turnPosition ||
        member.turnPosition < Number(capacitySummary.minimumEligibleTurn || 0)
      ) {
        throw new AppError(
          'L ordre des tours n est pas valide pour tous les membres actifs.',
          422,
        );
      }
    }

    await existingGroup.update(
      {
        startedAt: new Date(),
        launchStatus: 'started',
      },
      { transaction },
    );
    await ensureContributionScheduleForGroup(existingGroup, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_launch_started',
      entityType: 'agentGroup',
      entityId: existingGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: existingGroup.reference,
        participantCount: existingGroup.participantCount,
        memberCount: existingGroup.memberCount,
      },
      transaction,
    });

    return existingGroup;
  });

  return serializeGroupWithTurnSummary(group);
}

async function postponeGroupLaunch(agentProfile, groupId, payload, requestContext = {}) {
  const plannedStartDate = parsePlannedStartDate(payload?.plannedStartDate);
  if (!plannedStartDate) {
    throw new AppError('La nouvelle date de debut envisagee est invalide.', 422);
  }

  const group = await sequelize.transaction(async (transaction) => {
    const existingGroup = await findOwnedGroup(agentProfile.id, groupId, transaction);
    if (existingGroup.startedAt) {
      throw new AppError('Un groupe deja demarre ne peut pas etre prolonge.', 422);
    }

    await existingGroup.update(
      {
        plannedStartDate,
        launchCancelledAt: null,
        launchCancellationReason: null,
      },
      { transaction },
    );
    await syncLaunchStatus(existingGroup, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_launch_postponed',
      entityType: 'agentGroup',
      entityId: existingGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: existingGroup.reference,
        plannedStartDate,
      },
      transaction,
    });

    return existingGroup;
  });

  return serializeGroup(group);
}

async function reduceGroupTargetToCurrentMembers(
  agentProfile,
  groupId,
  requestContext = {},
) {
  const membersService = require('./agent-group-members.service');
  const group = await sequelize.transaction(async (transaction) => {
    const existingGroup = await findOwnedGroup(agentProfile.id, groupId, transaction);
    if (existingGroup.startedAt) {
      throw new AppError('Un groupe deja demarre ne peut pas etre reduit.', 422);
    }
    if (Number(existingGroup.memberCount) < 2) {
      throw new AppError(
        'Il faut au moins 2 participants actuels pour reduire le nombre cible.',
        422,
      );
    }
    if (Number(existingGroup.memberCount) >= Number(existingGroup.participantCount)) {
      throw new AppError(
        'Le nombre actuel atteint deja ou depasse le nombre cible.',
        422,
      );
    }

    await existingGroup.update(
      {
        participantCount: existingGroup.memberCount,
        launchCancelledAt: null,
        launchCancellationReason: null,
      },
      { transaction },
    );
    await membersService.recalculateGroupTurnOrder(existingGroup, transaction);
    await syncLaunchStatus(existingGroup, transaction);

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_target_reduced_to_current_members',
      entityType: 'agentGroup',
      entityId: existingGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: existingGroup.reference,
        participantCount: existingGroup.participantCount,
        memberCount: existingGroup.memberCount,
      },
      transaction,
    });

    return existingGroup;
  });

  return serializeGroupWithTurnSummary(group);
}

async function cancelGroupLaunch(agentProfile, groupId, payload, requestContext = {}) {
  const reason = String(payload?.reason || '').trim();
  if (!reason) {
    throw new AppError('Le motif d annulation du lancement est requis.', 422);
  }

  const group = await sequelize.transaction(async (transaction) => {
    const existingGroup = await findOwnedGroup(agentProfile.id, groupId, transaction);
    if (existingGroup.startedAt) {
      throw new AppError('Un groupe deja demarre ne peut pas etre annule.', 422);
    }

    await existingGroup.update(
      {
        launchCancelledAt: new Date(),
        launchCancellationReason: reason,
        launchStatus: 'launch_cancelled',
      },
      { transaction },
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_launch_cancelled',
      entityType: 'agentGroup',
      entityId: existingGroup.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: existingGroup.reference,
        reason,
      },
      transaction,
    });

    return existingGroup;
  });

  return serializeGroup(group);
}

module.exports = {
  listGroups,
  getGroupDetail,
  createGroup,
  updateGroup,
  changeGroupStatus,
  launchGroup,
  postponeGroupLaunch,
  reduceGroupTargetToCurrentMembers,
  cancelGroupLaunch,
  findOwnedGroup,
  serializeGroup,
  syncGroupMembershipState,
};
