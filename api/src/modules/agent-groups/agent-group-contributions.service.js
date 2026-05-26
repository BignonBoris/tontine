const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const { applyAgentBalanceChange, generateCashReference } = require('../agent-cash/agent-cash.service');
const { findOwnedGroup } = require('./agent-groups.service');

function addTurns(baseDate, intervalValue, intervalUnit, turnOffset) {
  const result = new Date(baseDate);
  const value = Number(intervalValue || 0) * Number(turnOffset || 0);
  if (intervalUnit === 'day') {
    result.setDate(result.getDate() + value);
  } else if (intervalUnit === 'week') {
    result.setDate(result.getDate() + value * 7);
  } else {
    result.setMonth(result.getMonth() + value);
  }
  return result;
}

function serializeContribution(contribution) {
  return {
    id: contribution.id,
    groupId: contribution.groupId,
    memberId: contribution.memberId,
    beneficiaryMemberId: contribution.beneficiaryMemberId,
    turnNumber: Number(contribution.turnNumber),
    dueDate: contribution.dueDate,
    amount: Number(contribution.amount),
    status: contribution.status,
    paymentSource: contribution.paymentSource,
    paidAt: contribution.paidAt,
    member: contribution.member?.client
      ? {
          id: contribution.member.client.id,
          displayName: contribution.member.client.displayName,
          phoneNumber: displayPhone(contribution.member.client.phoneNumber),
        }
      : null,
    beneficiary: contribution.beneficiaryMember?.client
      ? {
          id: contribution.beneficiaryMember.client.id,
          displayName: contribution.beneficiaryMember.client.displayName,
          phoneNumber: displayPhone(contribution.beneficiaryMember.client.phoneNumber),
        }
      : null,
  };
}

async function ensureContributionScheduleForGroup(group, transaction) {
  const existingCount = await models.AgentGroupContribution.count({
    where: { groupId: group.id },
    transaction,
  });
  if (existingCount > 0) {
    return;
  }

  const members = await models.AgentGroupMember.findAll({
    where: { groupId: group.id, status: 'active' },
    order: [['turnPosition', 'ASC']],
    transaction,
  });

  if (members.length !== Number(group.participantCount || 0)) {
    throw new AppError(
      'Impossible de generer les contributions sans ordre de tours complet.',
      422,
    );
  }

  const beneficiaryByTurn = new Map(
    members.map((member) => [Number(member.turnPosition), member]),
  );

  for (let turnNumber = 1; turnNumber <= Number(group.participantCount); turnNumber += 1) {
    const beneficiary = beneficiaryByTurn.get(turnNumber);
    if (!beneficiary) {
      throw new AppError(
        'Impossible de generer les contributions : un tour est sans beneficiaire.',
        422,
      );
    }

    const dueDate = addTurns(
      group.plannedStartDate,
      group.turnIntervalValue,
      group.turnIntervalUnit,
      turnNumber - 1,
    );

    for (const member of members) {
      await models.AgentGroupContribution.create(
        {
          groupId: group.id,
          memberId: member.id,
          beneficiaryMemberId: beneficiary.id,
          turnNumber,
          dueDate,
          amount: group.contributionAmount,
          status: 'pending',
        },
        { transaction },
      );
    }
  }
}

async function listGroupContributions(agentProfileId, groupId, filters = {}) {
  const group = await findOwnedGroup(agentProfileId, groupId);
  const turnNumber = Number(filters.turnNumber || 0);

  const where = {
    groupId: group.id,
    ...(turnNumber > 0 ? { turnNumber } : {}),
  };

  const contributions = await models.AgentGroupContribution.findAll({
    where,
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
    order: [['turnNumber', 'ASC'], ['createdAt', 'ASC']],
  });

  const grouped = new Map();
  for (const contribution of contributions) {
    const turn = Number(contribution.turnNumber);
    const existing = grouped.get(turn) || {
      turnNumber: turn,
      dueDate: contribution.dueDate,
      amount: Number(contribution.amount),
      beneficiary: contribution.beneficiaryMember?.client
        ? {
            id: contribution.beneficiaryMember.client.id,
            displayName: contribution.beneficiaryMember.client.displayName,
            phoneNumber: displayPhone(contribution.beneficiaryMember.client.phoneNumber),
          }
        : null,
      contributions: [],
    };
    existing.contributions.push(serializeContribution(contribution));
    grouped.set(turn, existing);
  }

  return Array.from(grouped.values());
}

async function payContributionByAgent(
  agentProfile,
  groupId,
  contributionId,
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const group = await findOwnedGroup(agentProfile.id, groupId, transaction);
    if (!group.startedAt) {
      throw new AppError(
        'Les contributions de groupe ne sont possibles qu apres le lancement.',
        422,
      );
    }

    const contribution = await models.AgentGroupContribution.findOne({
      where: { id: contributionId, groupId: group.id },
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
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!contribution) {
      throw new AppError('Contribution de groupe introuvable.', 404);
    }
    if (contribution.status === 'paid') {
      throw new AppError('Cette contribution est deja reglee.', 409);
    }

    const amount = Number(contribution.amount);
    await contribution.update(
      {
        status: 'paid',
        paymentSource: 'agent_cash',
        paidAt: new Date(),
        paidByAgentProfileId: agentProfile.id,
        paidByUserId: agentProfile.userId,
      },
      { transaction },
    );

    await applyAgentBalanceChange(
      agentProfile.id,
      {
        amount,
        isCredit: true,
        type: 'clientDeposit',
        label: `Cotisation groupe tour ${contribution.turnNumber}`,
        note: `Encaissement groupe ${group.reference}`,
        relatedEntityType: 'agentGroupContribution',
        relatedEntityId: contribution.id,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'agent.group_contribution_collected',
        reference: generateCashReference('GCT'),
      },
      transaction,
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_contribution_paid',
      entityType: 'agentGroupContribution',
      entityId: contribution.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        memberId: contribution.memberId,
        beneficiaryMemberId: contribution.beneficiaryMemberId,
        turnNumber: contribution.turnNumber,
        amount,
        paymentSource: 'agent_cash',
      },
      transaction,
    });

    return contribution;
  });

  return serializeContribution(result);
}

async function payContributionFromWallet(
  userId,
  contributionId,
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const contribution = await models.AgentGroupContribution.findByPk(contributionId, {
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
        {
          model: models.AgentGroup,
          as: 'group',
          required: true,
        },
      ],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!contribution || contribution.member?.clientUserId !== userId) {
      throw new AppError('Contribution de groupe introuvable pour ce client.', 404);
    }
    if (contribution.status === 'paid') {
      throw new AppError('Cette contribution est deja reglee.', 409);
    }

    const wallet = await models.Wallet.findOne({
      where: { userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });
    const amount = Number(contribution.amount);
    if (Number(wallet?.availableBalance || 0) < amount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance || 0) - amount,
      },
      { transaction },
    );

    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'tontineFunding',
        amount,
        label: `Cotisation groupe ${contribution.group.reference} tour ${contribution.turnNumber}`,
        isCredit: false,
      },
      { transaction },
    );

    await contribution.update(
      {
        status: 'paid',
        paymentSource: 'wallet',
        paidAt: new Date(),
        paidByUserId: userId,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'client.group_contribution_paid',
      entityType: 'agentGroupContribution',
      entityId: contribution.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: contribution.groupId,
        groupReference: contribution.group.reference,
        memberId: contribution.memberId,
        beneficiaryMemberId: contribution.beneficiaryMemberId,
        turnNumber: contribution.turnNumber,
        amount,
        paymentSource: 'wallet',
      },
      transaction,
    });

    return contribution;
  });

  return serializeContribution(result);
}

module.exports = {
  ensureContributionScheduleForGroup,
  listGroupContributions,
  payContributionByAgent,
  payContributionFromWallet,
  serializeContribution,
};
