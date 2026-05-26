const AppError = require('../../common/errors/app-error');
const { models } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const { serializeGroup } = require('../agent-groups/agent-groups.service');
const { serializeContribution, payContributionFromWallet } = require('../agent-groups/agent-group-contributions.service');

function serializeClientGroupMembership(membership) {
  const group = membership.group;
  if (!group) {
    return null;
  }

  return {
    ...serializeGroup(group),
    membership: {
      id: membership.id,
      status: membership.status,
      joinedAt: membership.joinedAt,
      removedAt: membership.removedAt,
      removalReason: membership.removalReason,
    },
    agent: group.agentProfile?.user
      ? {
          id: group.agentProfile.user.id,
          displayName: group.agentProfile.user.displayName,
          phoneNumber: displayPhone(group.agentProfile.user.phoneNumber),
        }
      : null,
  };
}

async function listMyGroups(userId) {
  const memberships = await models.AgentGroupMember.findAll({
    where: {
      clientUserId: userId,
      status: 'active',
    },
    include: [
      {
        model: models.AgentGroup,
        as: 'group',
        required: true,
        include: [
          {
            model: models.AgentProfile,
            as: 'agentProfile',
            required: false,
            include: [
              {
                model: models.User,
                as: 'user',
                required: false,
              },
            ],
          },
        ],
      },
    ],
    order: [
      [{ model: models.AgentGroup, as: 'group' }, 'plannedStartDate', 'ASC'],
      ['joinedAt', 'ASC'],
      ['createdAt', 'ASC'],
    ],
  });

  return memberships
    .map((membership) => serializeClientGroupMembership(membership))
    .filter(Boolean);
}

async function listMyGroupRequests(userId) {
  const memberships = await models.AgentGroupMember.findAll({
    where: {
      clientUserId: userId,
      status: 'requested',
    },
    include: [
      {
        model: models.AgentGroup,
        as: 'group',
        required: true,
        include: [
          {
            model: models.AgentProfile,
            as: 'agentProfile',
            required: false,
            include: [
              {
                model: models.User,
                as: 'user',
                required: false,
              },
            ],
          },
        ],
      },
    ],
    order: [
      ['joinedAt', 'DESC'],
      ['createdAt', 'DESC'],
    ],
  });

  return memberships
    .filter((membership) => {
      const group = membership.group;
      return group && group.status === 'active' && !group.startedAt;
    })
    .map((membership) => serializeClientGroupMembership(membership))
    .filter(Boolean);
}

async function getMyGroupDetail(userId, groupId) {
  const membership = await models.AgentGroupMember.findOne({
    where: {
      clientUserId: userId,
      groupId,
      status: 'active',
    },
    include: [
      {
        model: models.AgentGroup,
        as: 'group',
        required: true,
        include: [
          {
            model: models.AgentProfile,
            as: 'agentProfile',
            required: false,
            include: [
              {
                model: models.User,
                as: 'user',
                required: false,
              },
            ],
          },
        ],
      },
    ],
  });

  if (!membership) {
    throw new AppError('Groupe introuvable dans vos adhesions actives.', 404);
  }

  return serializeClientGroupMembership(membership);
}

async function listMyGroupContributions(userId, groupId) {
  const membership = await models.AgentGroupMember.findOne({
    where: {
      clientUserId: userId,
      groupId,
      status: 'active',
    },
  });

  if (!membership) {
    throw new AppError('Groupe introuvable dans vos adhesions actives.', 404);
  }

  const contributions = await models.AgentGroupContribution.findAll({
    where: { groupId, memberId: membership.id },
    include: [
      {
        model: models.AgentGroupMember,
        as: 'member',
        required: true,
        include: [{ model: models.User, as: 'client', required: false }],
      },
      {
        model: models.AgentGroupMember,
        as: 'beneficiaryMember',
        required: true,
        include: [{ model: models.User, as: 'client', required: false }],
      },
    ],
    order: [['turnNumber', 'ASC']],
  });

  return contributions.map((contribution) => serializeContribution(contribution));
}

module.exports = {
  listMyGroups,
  listMyGroupRequests,
  getMyGroupDetail,
  listMyGroupContributions,
  payContributionFromWallet,
};
