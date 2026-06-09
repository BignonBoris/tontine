const { models } = require('../../database/models');
const { buildInvitationToken, serializeInvitation } = require('../group-invitations/group-invitations.service');

async function listMyPendingGroupInvitations(userId) {
  const memberships = await models.AgentGroupMember.findAll({
    where: {
      clientUserId: userId,
      status: 'invited',
    },
    include: [
      {
        model: models.AgentGroup,
        as: 'group',
        required: true,
      },
    ],
    order: [['createdAt', 'DESC']],
  });

  return memberships
    .filter((membership) => {
      const group = membership.group;
      return (
        group &&
        group.status === 'active' &&
        !group.startedAt &&
        !group.launchCancelledAt &&
        Number(group.memberCount) < Number(group.participantCount)
      );
    })
    .map((membership) => {
      const token = buildInvitationToken(membership.group, {
        memberId: membership.id,
        clientUserId: membership.clientUserId,
      });
      return serializeInvitation(membership.group, token, {
        memberId: membership.id,
        clientUserId: membership.clientUserId,
      });
    });
}

module.exports = {
  listMyPendingGroupInvitations,
};
