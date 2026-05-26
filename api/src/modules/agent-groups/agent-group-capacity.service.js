const { Op } = require('sequelize');
const { models } = require('../../database/models');

function toAmount(value) {
  return Number(value || 0);
}

async function getClientFinancialSnapshot(userId, transaction = null) {
  const [wallet, goals, activeCycle] = await Promise.all([
    models.Wallet.findOne({
      where: { userId },
      transaction,
    }),
    models.Goal.findAll({
      where: { userId, status: 'active' },
      transaction,
    }),
    models.TontineCycle.findOne({
      where: {
        userId,
        status: { [Op.in]: ['active', 'enAttenteValidationFin'] },
      },
      order: [['createdAt', 'DESC']],
      transaction,
    }),
  ]);

  const availableBalance = toAmount(wallet?.availableBalance);
  const totalGoals = goals.reduce(
    (sum, goal) => sum + toAmount(goal.currentAmount),
    0,
  );
  const tontineBalance = toAmount(wallet?.tontineBalance);
  const tontineStake = activeCycle ? toAmount(activeCycle.stakeAmount) : 0;
  const tontineContributionCredit = Math.max(tontineBalance - tontineStake, 0);

  return {
    availableBalance,
    totalGoals,
    tontineBalance,
    tontineStake,
    tontineContributionCredit,
    estimatedCapacity:
      availableBalance + totalGoals + tontineContributionCredit,
  };
}

function computeMinimumEligibleTurn({
  estimatedNetCapacity,
  participantCount,
  contributionAmount,
}) {
  const normalizedParticipants = Number(participantCount || 0);
  const normalizedContribution = toAmount(contributionAmount);
  const normalizedCapacity = toAmount(estimatedNetCapacity);

  for (let turn = 1; turn <= normalizedParticipants; turn += 1) {
    const remainingCommitment =
      Math.max(normalizedParticipants - turn, 0) * normalizedContribution;
    if (normalizedCapacity >= remainingCommitment) {
      return turn;
    }
  }

  return normalizedParticipants + 1;
}

function computeReservedDebtForTurn({
  participantCount,
  contributionAmount,
  turnPosition,
}) {
  const normalizedTurn = Number(turnPosition || 0);
  if (!normalizedTurn) {
    return 0;
  }

  return (
    Math.max(Number(participantCount || 0) - normalizedTurn, 0) *
    toAmount(contributionAmount)
  );
}

async function getActiveGroupDebtForUser(
  userId,
  { excludeGroupId = null, transaction = null } = {},
) {
  const memberships = await models.AgentGroupMember.findAll({
    where: {
      clientUserId: userId,
      status: 'active',
      ...(excludeGroupId ? { groupId: { [Op.ne]: excludeGroupId } } : {}),
    },
    include: [
      {
        model: models.AgentGroup,
        as: 'group',
        required: true,
      },
    ],
    transaction,
  });

  let totalDebt = 0;
  for (const membership of memberships) {
    const group = membership.group;
    if (
      !group ||
      group.status !== 'active' ||
      group.launchCancelledAt
    ) {
      continue;
    }

    if (group.startedAt) {
      const paidPostTurnCount = await models.AgentGroupContribution.count({
        where: {
          groupId: group.id,
          memberId: membership.id,
          status: 'paid',
          turnNumber: {
            [Op.gt]: Number(membership.turnPosition || 0),
          },
        },
        transaction,
      });

      const remainingPostTurnCount = Math.max(
        Number(group.participantCount || 0) -
          Number(membership.turnPosition || 0) -
          Number(paidPostTurnCount || 0),
        0,
      );

      totalDebt += remainingPostTurnCount * toAmount(group.contributionAmount);
      continue;
    }

    totalDebt +=
      computeReservedDebtForTurn({
        participantCount: group.participantCount,
        contributionAmount: group.contributionAmount,
        turnPosition: membership.turnPosition,
      });
  }

  return totalDebt;
}

async function getClientGroupCapacityProfile(
  userId,
  {
    groupId = null,
    participantCount,
    contributionAmount,
    transaction = null,
  } = {},
) {
  const financialSnapshot = await getClientFinancialSnapshot(userId, transaction);
  const activeGroupDebt = await getActiveGroupDebtForUser(userId, {
    excludeGroupId: groupId,
    transaction,
  });
  const netEstimatedCapacity = Math.max(
    financialSnapshot.estimatedCapacity - activeGroupDebt,
    0,
  );
  const minimumEligibleTurn = computeMinimumEligibleTurn({
    estimatedNetCapacity: netEstimatedCapacity,
    participantCount,
    contributionAmount,
  });

  return {
    ...financialSnapshot,
    activeGroupDebt,
    netEstimatedCapacity,
    minimumEligibleTurn,
    canBeRanked: minimumEligibleTurn <= Number(participantCount || 0),
  };
}

module.exports = {
  getClientFinancialSnapshot,
  getActiveGroupDebtForUser,
  getClientGroupCapacityProfile,
  computeMinimumEligibleTurn,
  computeReservedDebtForTurn,
};
