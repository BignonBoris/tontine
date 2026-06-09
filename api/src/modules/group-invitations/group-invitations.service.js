const jwt = require('jsonwebtoken');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const env = require('../../config/env');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const {
  findOwnedGroup,
  serializeGroup,
  syncGroupMembershipState,
} = require('../agent-groups/agent-groups.service');
const {
  recalculateGroupTurnOrder,
} = require('../agent-groups/agent-group-members.service');

const INVITATION_SCOPE = 'group_invitation';
const INVITATION_EXPIRES_IN = '7d';

function buildInvitationToken(group, options = {}) {
  return jwt.sign(
    {
      scope: INVITATION_SCOPE,
      groupId: group.id,
      agentProfileId: group.agentProfileId,
      reference: group.reference,
      ...(options.memberId ? { memberId: options.memberId } : {}),
      ...(options.clientUserId ? { clientUserId: options.clientUserId } : {}),
    },
    env.jwtSecret,
    { expiresIn: INVITATION_EXPIRES_IN },
  );
}

function verifyInvitationToken(token) {
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    if (payload.scope !== INVITATION_SCOPE || !payload.groupId) {
      throw new AppError('Invitation de groupe invalide.', 422);
    }
    return payload;
  } catch (error) {
    throw error instanceof AppError
      ? error
      : new AppError('Invitation de groupe invalide ou expiree.', 422);
  }
}

function getShareUrl(token) {
  const explicitClientBaseUrl = process.env.CLIENT_APP_BASE_URL;
  const baseUrl = String(env.clientAppBaseUrl || env.appBaseUrl || '').replace(
    /\/$/,
    '',
  );

  if (explicitClientBaseUrl) {
    return `${baseUrl}/group-invitations/${token}`;
  }

  return `${baseUrl}/api/v1/group-invitations/${token}`;
}

function getApiPreviewUrl(token) {
  const baseUrl = String(env.appBaseUrl || '').replace(/\/$/, '');
  return `${baseUrl}/api/v1/group-invitations/${token}`;
}

function serializeInvitation(group, token, options = {}) {
  return {
    token,
    shareUrl: getShareUrl(token),
    previewUrl: getApiPreviewUrl(token),
    invitationType: options.memberId ? 'targeted' : 'open',
    invitation: {
      groupId: group.id,
      reference: group.reference,
      groupName: group.name,
      participantCount: Number(group.participantCount),
      memberCount: Number(group.memberCount),
      remainingSlots: Math.max(
        Number(group.participantCount) - Number(group.memberCount),
        0,
      ),
      plannedStartDate: group.plannedStartDate,
      launchStatus: group.launchStatus,
      contributionAmount: Number(group.contributionAmount),
      turnIntervalValue: Number(group.turnIntervalValue),
      turnIntervalUnit: group.turnIntervalUnit,
      description: group.description,
    },
  };
}

async function assertInvitableGroup(group) {
  if (group.status !== 'active') {
    throw new AppError(
      'Seuls les groupes actifs peuvent partager un lien d invitation.',
      422,
    );
  }
  if (group.startedAt) {
    throw new AppError(
      'Un groupe deja demarre ne peut plus partager de lien d invitation.',
      422,
    );
  }
  if (group.launchCancelledAt) {
    throw new AppError(
      'Le lancement de ce groupe est annule. Reactivez ou modifiez le groupe avant de partager une invitation.',
      422,
    );
  }
  if (Number(group.memberCount) >= Number(group.participantCount)) {
    throw new AppError(
      'Le groupe a deja atteint son nombre cible. Aucun lien d invitation supplementaire n est necessaire.',
      422,
    );
  }
}

async function generateInvitationLink(agentProfile, groupId, requestContext = {}) {
  const group = await findOwnedGroup(agentProfile.id, groupId);
  await assertInvitableGroup(group);

  const token = buildInvitationToken(group);

  await writeAuditLog({
    userId: agentProfile.userId,
    action: 'agent.group_invitation_link_generated',
    entityType: 'agentGroup',
    entityId: group.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      reference: group.reference,
      memberCount: group.memberCount,
      participantCount: group.participantCount,
    },
  });

  return serializeInvitation(group, token);
}

async function generateMemberInvitationLink(
  agentProfile,
  groupId,
  memberId,
  requestContext = {},
) {
  const group = await findOwnedGroup(agentProfile.id, groupId);
  await assertInvitableGroup(group);

  const member = await models.AgentGroupMember.findOne({
    where: {
      id: memberId,
      groupId: group.id,
      status: 'invited',
    },
  });

  if (!member) {
    throw new AppError(
      'Invitation nominative introuvable pour ce participant.',
      404,
    );
  }

  const token = buildInvitationToken(group, {
    memberId: member.id,
    clientUserId: member.clientUserId,
  });

  await writeAuditLog({
    userId: agentProfile.userId,
    action: 'agent.group_member_invitation_link_generated',
    entityType: 'agentGroupMember',
    entityId: member.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      groupId: group.id,
      groupReference: group.reference,
      clientUserId: member.clientUserId,
    },
  });

  return serializeInvitation(group, token, {
    memberId: member.id,
    clientUserId: member.clientUserId,
  });
}

async function getInvitationPreview(token) {
  const payload = verifyInvitationToken(token);
  const group = await models.AgentGroup.findByPk(payload.groupId);
  if (!group) {
    throw new AppError('Groupe introuvable pour cette invitation.', 404);
  }
  await assertInvitableGroup(group);
  if (payload.memberId) {
    const member = await models.AgentGroupMember.findOne({
      where: {
        id: payload.memberId,
        groupId: group.id,
        clientUserId: payload.clientUserId,
        status: 'invited',
      },
    });

    if (!member) {
      throw new AppError(
        'Cette invitation nominative n est plus disponible.',
        422,
      );
    }
  }
  return serializeInvitation(group, token, payload);
}

async function acceptInvitation(token, userId, requestContext = {}) {
  const payload = verifyInvitationToken(token);

  const result = await sequelize.transaction(async (transaction) => {
    const group = await models.AgentGroup.findByPk(payload.groupId, {
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!group) {
      throw new AppError('Groupe introuvable pour cette invitation.', 404);
    }

    await assertInvitableGroup(group);

    const user = await models.User.findOne({
      where: { id: userId, isActive: true },
      include: [{ model: models.AgentProfile, as: 'agentProfile', required: false }],
      transaction,
    });

    if (!user || user.agentProfile) {
      throw new AppError(
        'Seul un client actif peut accepter une invitation de groupe.',
        403,
      );
    }

    if (payload.clientUserId && payload.clientUserId !== user.id) {
      throw new AppError(
        'Cette invitation est reservee a un autre client.',
        403,
      );
    }

    const existingMember = await models.AgentGroupMember.findOne({
      where: {
        groupId: group.id,
        clientUserId: user.id,
        ...(payload.memberId ? { id: payload.memberId } : {}),
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (existingMember?.status === 'active') {
      throw new AppError('Vous etes deja membre actif de ce groupe.', 409);
    }

    if (payload.memberId && ['removed', 'declined'].includes(existingMember?.status)) {
      throw new AppError(
        'Votre participation a ete retiree de ce groupe. Contactez l agent pour etre ajoute de nouveau.',
        422,
      );
    }

    if (!payload.memberId && existingMember?.status === 'invited') {
      throw new AppError(
        'Une invitation nominative est deja en attente pour vous dans ce groupe.',
        409,
      );
    }

    if (!payload.memberId && existingMember?.status === 'requested') {
      throw new AppError(
        'Votre demande d adhesion est deja en attente de validation par l agent.',
        409,
      );
    }

    if (Number(group.memberCount) >= Number(group.participantCount)) {
      throw new AppError(
        'Le groupe a atteint son nombre cible avant votre acceptation.',
        422,
      );
    }

    let member;
    if (payload.memberId && !existingMember) {
      throw new AppError(
        'Cette invitation nominative n est plus disponible.',
        422,
      );
    }

    if (payload.memberId) {
      if (existingMember) {
        member = await existingMember.update(
          {
            status: 'active',
            joinedAt: new Date(),
            removedAt: null,
            removalReason: null,
            removedByUserId: null,
            addedByUserId: user.id,
          },
          { transaction },
        );
      } else {
        member = await models.AgentGroupMember.create(
          {
            groupId: group.id,
            clientUserId: user.id,
            status: 'active',
            joinedAt: new Date(),
            addedByUserId: user.id,
          },
          { transaction },
        );
      }

      const activeCount = await models.AgentGroupMember.count({
        where: { groupId: group.id, status: 'active' },
        transaction,
      });

      await group.update({ memberCount: activeCount }, { transaction });
      await syncGroupMembershipState(group, transaction);
      await recalculateGroupTurnOrder(group, transaction);

      await writeAuditLog({
        userId,
        action: 'client.group_invitation_accepted',
        entityType: 'agentGroupMember',
        entityId: member.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          groupId: group.id,
          groupReference: group.reference,
          clientUserId: user.id,
        },
        transaction,
      });

      return { group, user, memberStatus: 'active', invitationType: 'targeted' };
    }

    if (existingMember) {
      member = await existingMember.update(
        {
          status: 'requested',
          joinedAt: new Date(),
          removedAt: null,
          removalReason: 'Demande d adhesion envoyee par le client',
          removedByUserId: null,
        },
        { transaction },
      );
    } else {
      member = await models.AgentGroupMember.create(
        {
          groupId: group.id,
          clientUserId: user.id,
          status: 'requested',
          joinedAt: new Date(),
          addedByUserId: user.id,
        },
        { transaction },
      );
    }

    await syncGroupMembershipState(group, transaction);
    await recalculateGroupTurnOrder(group, transaction);

    await writeAuditLog({
      userId,
      action: 'client.group_join_requested',
      entityType: 'agentGroupMember',
      entityId: member.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        clientUserId: user.id,
      },
      transaction,
    });

    return { group, user, memberStatus: 'requested', invitationType: 'open' };
  });

  return {
    group: serializeGroup(result.group),
    invitationType: result.invitationType,
    memberStatus: result.memberStatus,
    acceptedBy: {
      id: result.user.id,
      displayName: result.user.displayName,
      phoneNumber: displayPhone(result.user.phoneNumber),
    },
  };
}

async function declineInvitation(token, userId, requestContext = {}) {
  const payload = verifyInvitationToken(token);
  if (!payload.memberId || !payload.clientUserId) {
    throw new AppError(
      'Seule une invitation nominative peut etre refusee.',
      422,
    );
  }

  const result = await sequelize.transaction(async (transaction) => {
    const group = await models.AgentGroup.findByPk(payload.groupId, {
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!group) {
      throw new AppError('Groupe introuvable pour cette invitation.', 404);
    }

    const user = await models.User.findOne({
      where: { id: userId, isActive: true },
      include: [{ model: models.AgentProfile, as: 'agentProfile', required: false }],
      transaction,
    });

    if (!user || user.agentProfile) {
      throw new AppError(
        'Seul un client actif peut refuser une invitation de groupe.',
        403,
      );
    }

    if (payload.clientUserId !== user.id) {
      throw new AppError(
        'Cette invitation est reservee a un autre client.',
        403,
      );
    }

    const member = await models.AgentGroupMember.findOne({
      where: {
        id: payload.memberId,
        groupId: group.id,
        clientUserId: user.id,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!member || member.status !== 'invited') {
      throw new AppError(
        'Cette invitation n est plus en attente de reponse.',
        422,
      );
    }

    await member.update(
      {
        status: 'declined',
        removedAt: new Date(),
        removalReason: 'Invitation refusee par le client',
        removedByUserId: user.id,
      },
      { transaction },
    );
    await recalculateGroupTurnOrder(group, transaction);

    await writeAuditLog({
      userId,
      action: 'client.group_invitation_declined',
      entityType: 'agentGroupMember',
      entityId: member.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        clientUserId: user.id,
      },
      transaction,
    });

    return { group, user };
  });

  return {
    group: serializeGroup(result.group),
    declinedBy: {
      id: result.user.id,
      displayName: result.user.displayName,
      phoneNumber: displayPhone(result.user.phoneNumber),
    },
  };
}

module.exports = {
  generateInvitationLink,
  generateMemberInvitationLink,
  getInvitationPreview,
  acceptInvitation,
  declineInvitation,
  buildInvitationToken,
  serializeInvitation,
};
