const AppError = require('../../common/errors/app-error');
const { Op } = require('sequelize');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const { applyAgentBalanceChange, generateCashReference } = require('../agent-cash/agent-cash.service');
const {
  getOrCreateCommissionWallet,
  generateReference: generateCommissionReference,
} = require('../commission/commission.service');
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
  const normalizedStatus =
    contribution.status === 'missed' ? 'pending' : contribution.status;
  return {
    id: contribution.id,
    groupId: contribution.groupId,
    memberId: contribution.memberId,
    beneficiaryMemberId: contribution.beneficiaryMemberId,
    turnNumber: Number(contribution.turnNumber),
    dueDate: contribution.dueDate,
    amount: Number(contribution.amount),
    status: normalizedStatus,
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

function serializeTurn(turn, contributions = []) {
  return {
    id: turn.id,
    groupId: turn.groupId,
    turnNumber: Number(turn.turnNumber),
    dueDate: turn.dueDate,
    amount: Number(turn.amount),
    status: turn.status,
    payoutMethod: turn.payoutMethod,
    payoutAt: turn.payoutAt,
    beneficiary: turn.beneficiaryMember?.client
      ? {
          id: turn.beneficiaryMember.client.id,
          displayName: turn.beneficiaryMember.client.displayName,
          phoneNumber: displayPhone(turn.beneficiaryMember.client.phoneNumber),
        }
      : null,
    contributions,
  };
}

function serializeAdvance(advance) {
  const amount = Number(advance.amount);
  const recoveredAmount = Number(advance.recoveredAmount || 0);
  return {
    id: advance.id,
    groupId: advance.groupId,
    contributionId: advance.contributionId,
    memberId: advance.memberId,
    beneficiaryMemberId: advance.beneficiaryMemberId,
    agentProfileId: advance.agentProfileId,
    amount,
    recoveredAmount,
    remainingAmount: Math.max(amount - recoveredAmount, 0),
    status: advance.status,
    advancedAt: advance.advancedAt,
    recoveredAt: advance.recoveredAt,
    lastRecoveredAt: advance.lastRecoveredAt,
    member: advance.member?.client
      ? {
          id: advance.member.client.id,
          displayName: advance.member.client.displayName,
          phoneNumber: displayPhone(advance.member.client.phoneNumber),
        }
      : null,
    beneficiary: advance.beneficiaryMember?.client
      ? {
          id: advance.beneficiaryMember.client.id,
          displayName: advance.beneficiaryMember.client.displayName,
          phoneNumber: displayPhone(advance.beneficiaryMember.client.phoneNumber),
        }
      : null,
    contribution: advance.contribution
      ? {
          id: advance.contribution.id,
          turnNumber: Number(advance.contribution.turnNumber),
          dueDate: advance.contribution.dueDate,
          status: advance.contribution.status,
          paymentSource: advance.contribution.paymentSource,
          paidAt: advance.contribution.paidAt,
        }
      : null,
  };
}

function serializeAdvanceRecovery(recovery) {
  return {
    id: recovery.id,
    advanceId: recovery.advanceId,
    groupId: recovery.groupId,
    contributionId: recovery.contributionId,
    memberId: recovery.memberId,
    beneficiaryMemberId: recovery.beneficiaryMemberId,
    agentProfileId: recovery.agentProfileId,
    reference: recovery.reference,
    amount: Number(recovery.amount),
    recoveredAt: recovery.recoveredAt,
    member: recovery.member?.client
      ? {
          id: recovery.member.client.id,
          displayName: recovery.member.client.displayName,
          phoneNumber: displayPhone(recovery.member.client.phoneNumber),
        }
      : null,
    beneficiary: recovery.beneficiaryMember?.client
      ? {
          id: recovery.beneficiaryMember.client.id,
          displayName: recovery.beneficiaryMember.client.displayName,
          phoneNumber: displayPhone(recovery.beneficiaryMember.client.phoneNumber),
        }
      : null,
    contribution: recovery.contribution
      ? {
          id: recovery.contribution.id,
          turnNumber: Number(recovery.contribution.turnNumber),
          dueDate: recovery.contribution.dueDate,
        }
      : null,
  };
}

function splitGroupCommission(commissionAmount) {
  const totalAmount = Number(commissionAmount || 0);
  const platformCommissionAmount = Number((totalAmount * 0.25).toFixed(2));
  const agentCommissionAmount = Number(
    (totalAmount - platformCommissionAmount).toFixed(2),
  );

  return {
    platformCommissionAmount,
    agentCommissionAmount,
  };
}

async function appendNotification(transaction, userId, type, title, message) {
  if (!userId) {
    return null;
  }

  return models.Notification.create(
    {
      userId,
      type,
      title,
      message,
    },
    { transaction },
  );
}

async function syncTurnStatus(turn, transaction) {
  if (turn.status === 'paid') {
    return turn;
  }

  const paidCount = await models.AgentGroupContribution.count({
    where: {
      groupId: turn.groupId,
      turnNumber: turn.turnNumber,
      status: 'paid',
    },
    transaction,
  });

  const totalCount = await models.AgentGroupContribution.count({
    where: {
      groupId: turn.groupId,
      turnNumber: turn.turnNumber,
    },
    transaction,
  });

  let nextStatus = 'collecting';
  if (paidCount >= totalCount) {
    nextStatus = 'ready';
  }

  if (turn.status !== nextStatus) {
    const options = transaction ? { transaction } : undefined;
    await turn.update({ status: nextStatus }, options);
  }

  return turn;
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

    await models.AgentGroupTurn.create(
      {
        groupId: group.id,
        beneficiaryMemberId: beneficiary.id,
        turnNumber,
        dueDate,
        amount: Number(group.contributionAmount) * members.length,
        status: 'collecting',
      },
      { transaction },
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

  const turns = await models.AgentGroupTurn.findAll({
    where: {
      groupId: group.id,
      ...(turnNumber > 0 ? { turnNumber } : {}),
    },
    include: [
      {
        model: models.AgentGroupMember,
        as: 'beneficiaryMember',
        required: true,
        include: [{ model: models.User, as: 'client', required: false }],
      },
    ],
    order: [['turnNumber', 'ASC']],
  });

  const results = [];
  for (const turn of turns) {
    await syncTurnStatus(turn, null);
    const contributions = await models.AgentGroupContribution.findAll({
      where: { groupId: group.id, turnNumber: turn.turnNumber },
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
      order: [['createdAt', 'ASC']],
    });

    results.push(
      serializeTurn(
        turn,
        contributions.map((contribution) => serializeContribution(contribution)),
      ),
    );
  }

  return results;
}

async function listGroupAdvances(agentProfileId, groupId, filters = {}) {
  const group = await findOwnedGroup(agentProfileId, groupId);
  const status = String(filters.status || 'open').trim().toLowerCase();
  const where = { groupId: group.id };
  if (status === 'open') {
    where.status = { [Op.in]: ['outstanding', 'partially_recovered'] };
  } else if (status !== 'all') {
    where.status = status;
  }

  const advances = await models.AgentGroupAdvance.findAll({
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
      {
        model: models.AgentGroupContribution,
        as: 'contribution',
        required: true,
      },
    ],
    order: [['advancedAt', 'DESC'], ['createdAt', 'DESC']],
  });

  return advances.map((advance) => serializeAdvance(advance));
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
    const turn = await models.AgentGroupTurn.findOne({
      where: { groupId: group.id, turnNumber: contribution.turnNumber },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });
    await syncTurnStatus(turn, transaction);

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

    await appendNotification(
      transaction,
      contribution.member.clientUserId || contribution.member.client?.id,
      'system',
      'Cotisation encaissee',
      `Votre cotisation du tour ${contribution.turnNumber} du groupe ${group.reference} a ete encaissee. Montant: ${amount} F.`,
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

    await appendNotification(
      transaction,
      userId,
      'system',
      'Cotisation prelevee',
      `Votre cotisation du tour ${contribution.turnNumber} du groupe ${contribution.group.reference} a ete prelevee de votre solde disponible. Montant: ${amount} F.`,
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
    const turn = await models.AgentGroupTurn.findOne({
      where: {
        groupId: contribution.groupId,
        turnNumber: contribution.turnNumber,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });
    await syncTurnStatus(turn, transaction);

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

async function advanceContributionByAgent(
  agentProfile,
  groupId,
  contributionId,
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const group = await findOwnedGroup(agentProfile.id, groupId, transaction);
    if (!group.startedAt) {
      throw new AppError(
        'Les avances de groupe ne sont possibles qu apres le lancement.',
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

    await applyAgentBalanceChange(
      agentProfile.id,
      {
        amount,
        isCredit: false,
        type: 'adjustment',
        label: `Avance groupe tour ${contribution.turnNumber}`,
        note: `Avance agent pour groupe ${group.reference}`,
        relatedEntityType: 'agentGroupContribution',
        relatedEntityId: contribution.id,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'agent.group_contribution_advanced_from_cash',
        reference: generateCashReference('GAV'),
      },
      transaction,
    );

    await contribution.update(
      {
        status: 'paid',
        paymentSource: 'agent_advance',
        paidAt: new Date(),
        paidByAgentProfileId: agentProfile.id,
        paidByUserId: agentProfile.userId,
      },
      { transaction },
    );

    await models.AgentGroupAdvance.create(
      {
        groupId: group.id,
        contributionId: contribution.id,
        memberId: contribution.memberId,
        beneficiaryMemberId: contribution.beneficiaryMemberId,
        agentProfileId: agentProfile.id,
        amount,
        recoveredAmount: 0,
        status: 'outstanding',
        advancedAt: new Date(),
      },
      { transaction },
    );

    const turn = await models.AgentGroupTurn.findOne({
      where: { groupId: group.id, turnNumber: contribution.turnNumber },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });
    await syncTurnStatus(turn, transaction);

    await appendNotification(
      transaction,
      contribution.member.clientUserId || contribution.member.client?.id,
      'system',
      'Cotisation avancee',
      `Votre cotisation du tour ${contribution.turnNumber} du groupe ${group.reference} a ete avancee par l agent. Montant: ${amount} F.`,
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_contribution_advanced',
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
        paymentSource: 'agent_advance',
      },
      transaction,
    });

    return contribution;
  });

  return serializeContribution(result);
}

async function recoverAdvanceByAgent(
  agentProfile,
  groupId,
  advanceId,
  payload = {},
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const group = await findOwnedGroup(agentProfile.id, groupId, transaction);
    const advance = await models.AgentGroupAdvance.findOne({
      where: {
        id: advanceId,
        groupId: group.id,
        agentProfileId: agentProfile.id,
      },
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
          model: models.AgentGroupContribution,
          as: 'contribution',
          required: true,
        },
      ],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!advance) {
      throw new AppError('Avance groupe introuvable.', 404);
    }
    if (advance.status === 'recovered') {
      throw new AppError('Cette avance a deja ete totalement remboursee.', 409);
    }

    const totalAmount = Number(advance.amount);
    const recoveredAmount = Number(advance.recoveredAmount || 0);
    const remainingAmount = Math.max(totalAmount - recoveredAmount, 0);
    const requestedAmount = payload.amount == null
      ? remainingAmount
      : Number(payload.amount);

    if (!requestedAmount || requestedAmount <= 0) {
      throw new AppError('Montant de remboursement invalide.', 422);
    }
    if (requestedAmount > remainingAmount) {
      throw new AppError('Le remboursement depasse le solde de l avance.', 422);
    }

    await applyAgentBalanceChange(
      agentProfile.id,
      {
        amount: requestedAmount,
        isCredit: true,
        type: 'clientDeposit',
        label: `Remboursement avance groupe tour ${advance.contribution.turnNumber}`,
        note: `Remboursement client avance groupe ${group.reference}`,
        relatedEntityType: 'agentGroupAdvance',
        relatedEntityId: advance.id,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'agent.group_advance_recovered_to_cash',
        reference: generateCashReference('GAR'),
      },
      transaction,
    );

    const recoveryReference = generateCashReference('GRC');
    await models.AgentGroupAdvanceRecovery.create(
      {
        advanceId: advance.id,
        groupId: group.id,
        contributionId: advance.contributionId,
        memberId: advance.memberId,
        beneficiaryMemberId: advance.beneficiaryMemberId,
        agentProfileId: agentProfile.id,
        reference: recoveryReference,
        amount: requestedAmount,
        recoveredAt: new Date(),
      },
      { transaction },
    );

    const nextRecoveredAmount = recoveredAmount + requestedAmount;
    const nextStatus = nextRecoveredAmount >= totalAmount
      ? 'recovered'
      : 'partially_recovered';

    await advance.update(
      {
        recoveredAmount: nextRecoveredAmount,
        status: nextStatus,
        lastRecoveredAt: new Date(),
        recoveredAt: nextStatus === 'recovered' ? new Date() : null,
      },
      { transaction },
    );

    await models.Notification.create(
      {
        userId: advance.member.clientUserId || advance.member.client?.id,
        type: 'system',
        title: 'Remboursement d avance enregistre',
        message: `${requestedAmount} F rembourses sur votre avance du tour ${advance.contribution.turnNumber} du groupe ${group.name}. Reference ${recoveryReference}.`,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_advance_recovered',
      entityType: 'agentGroupAdvance',
      entityId: advance.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        memberId: advance.memberId,
        beneficiaryMemberId: advance.beneficiaryMemberId,
        contributionId: advance.contributionId,
        recoveredAmount: requestedAmount,
        totalRecoveredAmount: nextRecoveredAmount,
        advanceAmount: totalAmount,
        status: nextStatus,
      },
      transaction,
    });

    return advance;
  });

  return serializeAdvance(result);
}

async function listClientAdvanceRecoveries(userId, groupId) {
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

  const recoveries = await models.AgentGroupAdvanceRecovery.findAll({
    where: {
      groupId,
      memberId: membership.id,
    },
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
        model: models.AgentGroupContribution,
        as: 'contribution',
        required: true,
      },
    ],
    order: [['recoveredAt', 'DESC'], ['createdAt', 'DESC']],
  });

  return recoveries.map((recovery) => serializeAdvanceRecovery(recovery));
}

async function payoutTurnByAgent(
  agentProfile,
  groupId,
  turnId,
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const group = await findOwnedGroup(agentProfile.id, groupId, transaction);
    const turn = await models.AgentGroupTurn.findOne({
      where: { id: turnId, groupId: group.id },
      include: [
        {
          model: models.AgentGroupMember,
          as: 'beneficiaryMember',
          required: true,
          include: [{ model: models.User, as: 'client', required: true }],
        },
      ],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!turn) {
      throw new AppError('Tour introuvable pour ce groupe.', 404);
    }

    await syncTurnStatus(turn, transaction);
    if (turn.status === 'paid') {
      throw new AppError('Ce tour a deja ete verse.', 409);
    }

    if (turn.status !== 'ready') {
      throw new AppError(
        'Le beneficiarie ne peut etre verse que lorsque toutes les cotisations du tour sont reglees.',
        422,
      );
    }

    const grossAmount = Number(turn.amount);
    const commissionAmount = Number(group.commissionAmount || 0);
    if (commissionAmount > grossAmount) {
      throw new AppError('La commission du groupe depasse le montant du tour.', 422);
    }
    const { platformCommissionAmount, agentCommissionAmount } =
      splitGroupCommission(commissionAmount);
    const netAmount = grossAmount - commissionAmount;
    const beneficiaryUserId = turn.beneficiaryMember.clientUserId;
    const wallet = await models.Wallet.findOne({
      where: { userId: beneficiaryUserId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance || 0) + netAmount,
      },
      { transaction },
    );

    await models.AvailableBalanceHistory.create(
      {
        userId: beneficiaryUserId,
        type: 'tontinePayout',
        amount: netAmount,
        label: `Paiement groupe ${group.reference} tour ${turn.turnNumber}`,
        isCredit: true,
      },
      { transaction },
    );

    if (commissionAmount > 0) {
      const agentCommissionWallet = await getOrCreateCommissionWallet({
        transaction,
        ownerType: 'agent',
        ownerId: agentProfile.id,
        walletType: 'agent_commission',
      });

      await agentCommissionWallet.update(
        {
          balance: Number(agentCommissionWallet.balance || 0) + agentCommissionAmount,
          payableBalance:
            Number(agentCommissionWallet.payableBalance || 0) + agentCommissionAmount,
        },
        { transaction },
      );

      await models.CommissionLedgerEntry.create(
        {
          reference: generateCommissionReference('COM'),
          entryType: 'agent_group_turn_commission_credit',
          status: 'posted',
          sourceType: 'agent_group_turn',
          sourceId: turn.id,
          cycleId: null,
          clientId: null,
          agentId: agentProfile.id,
          walletId: agentCommissionWallet.id,
          direction: 'credit',
          amount: agentCommissionAmount,
          payableAmount: agentCommissionAmount,
          blockedAmount: 0,
          currency: 'XOF',
          commissionBucket: 'group_agent',
          snapshotId: null,
          triggerEvent: 'group_turn_paid_out',
          initiatorType: 'agent',
          initiatedByUserId: agentProfile.userId,
          metadata: {
            groupId: group.id,
            groupReference: group.reference,
            turnNumber: turn.turnNumber,
            grossAmount,
            commissionAmount,
            platformCommissionAmount,
            agentCommissionAmount,
            netAmount,
            beneficiaryUserId,
          },
        },
        { transaction },
      );

      if (platformCommissionAmount > 0) {
        const platformCommissionWallet = await getOrCreateCommissionWallet({
          transaction,
          ownerType: 'platform',
          ownerId: 'main',
          walletType: 'platform_commission',
        });

        await platformCommissionWallet.update(
          {
            balance:
              Number(platformCommissionWallet.balance || 0) + platformCommissionAmount,
            payableBalance:
              Number(platformCommissionWallet.payableBalance || 0) +
              platformCommissionAmount,
          },
          { transaction },
        );

        await models.CommissionLedgerEntry.create(
          {
            reference: generateCommissionReference('COM'),
            entryType: 'group_platform_commission_credit',
            status: 'posted',
            sourceType: 'agent_group_turn',
            sourceId: turn.id,
            cycleId: null,
            clientId: null,
            agentId: null,
            walletId: platformCommissionWallet.id,
            direction: 'credit',
            amount: platformCommissionAmount,
            payableAmount: platformCommissionAmount,
            blockedAmount: 0,
            currency: 'XOF',
            commissionBucket: 'group_platform',
            snapshotId: null,
            triggerEvent: 'group_turn_paid_out',
            initiatorType: 'agent',
            initiatedByUserId: agentProfile.userId,
            metadata: {
              groupId: group.id,
              groupReference: group.reference,
              turnNumber: turn.turnNumber,
              grossAmount,
              commissionAmount,
              platformCommissionAmount,
              agentCommissionAmount,
              netAmount,
              beneficiaryUserId,
            },
          },
          { transaction },
        );
      }

      await appendNotification(
        transaction,
        agentProfile.userId,
        'system',
        'Commission de tour creditee',
        `Votre commission du tour ${turn.turnNumber} du groupe ${group.reference} a ete creditee. Part agent: ${agentCommissionAmount} F, part plateforme: ${platformCommissionAmount} F.`,
      );
    }

    await models.Notification.create(
      {
        userId: beneficiaryUserId,
        type: 'system',
        title: 'Paiement du tour disponible',
        message: commissionAmount > 0
          ? `${netAmount} F verses pour le tour ${turn.turnNumber} du groupe ${group.name} apres commission de ${commissionAmount} F.`
          : `${netAmount} F verses pour le tour ${turn.turnNumber} du groupe ${group.name}.`,
      },
      { transaction },
    );

    await turn.update(
      {
        status: 'paid',
        payoutMethod: 'wallet',
        payoutAt: new Date(),
        paidByAgentProfileId: agentProfile.id,
        paidByUserId: agentProfile.userId,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.group_turn_paid_out',
      entityType: 'agentGroupTurn',
      entityId: turn.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        groupId: group.id,
        groupReference: group.reference,
        turnNumber: turn.turnNumber,
        grossAmount,
        commissionAmount,
        platformCommissionAmount,
        agentCommissionAmount,
        netAmount,
        beneficiaryUserId,
      },
      transaction,
    });

    return turn;
  });

  return serializeTurn(result);
}

module.exports = {
  ensureContributionScheduleForGroup,
  listGroupContributions,
  listGroupAdvances,
  payContributionByAgent,
  payContributionFromWallet,
  advanceContributionByAgent,
  recoverAdvanceByAgent,
  listClientAdvanceRecoveries,
  payoutTurnByAgent,
  serializeContribution,
  serializeTurn,
  serializeAdvance,
  serializeAdvanceRecovery,
};
