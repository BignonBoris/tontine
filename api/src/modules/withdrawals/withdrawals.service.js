const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const {
  consumeWithdrawalCommissionReserves,
  generateReference,
  postWithdrawalCommissions,
} = require('../commission/commission.service');

function serializeWithdrawal(withdrawal) {
  if (!withdrawal) {
    return null;
  }
  return {
    id: withdrawal.id,
    reference: withdrawal.reference,
    amount: Number(withdrawal.amount),
    status: withdrawal.status,
    channel: withdrawal.channel,
    requestedAt: withdrawal.requestedAt,
    paidAt: withdrawal.paidAt,
    cancelledAt: withdrawal.cancelledAt,
    rejectedAt: withdrawal.rejectedAt,
    notes: withdrawal.notes,
    payingAgent: withdrawal.payingAgent
      ? {
          id: withdrawal.payingAgent.id,
          agentCode: withdrawal.payingAgent.agentCode,
          fullName: withdrawal.payingAgent.fullName,
        }
      : null,
  };
}

async function listClientWithdrawals(userId) {
  const withdrawals = await models.Withdrawal.findAll({
    where: { userId },
    include: [{ model: models.AgentProfile, as: 'payingAgent', required: false }],
    order: [['createdAt', 'DESC']],
  });

  return withdrawals.map(serializeWithdrawal);
}

async function createWithdrawal(userId, payload, requestContext = {}) {
  const amount = Number(payload.amount);
  if (!amount || amount <= 0 || amount % 500 !== 0) {
    throw new AppError('Le montant du retrait doit etre un multiple positif de 500.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    if (!wallet) {
      throw new AppError('Portefeuille introuvable.', 404);
    }

    if (Number(wallet.availableBalance) < amount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    const withdrawal = await models.Withdrawal.create(
      {
        reference: generateReference('WDR'),
        userId,
        amount,
        status: 'requested',
        channel: 'cash',
        requestedAt: new Date(),
        initiatedByUserId: requestContext.initiatedByUserId || userId,
        initiatorType: requestContext.initiatorType || 'client',
      },
      { transaction },
    );

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) - amount,
        reservedWithdrawalBalance: Number(wallet.reservedWithdrawalBalance) + amount,
      },
      { transaction },
    );

    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'withdrawalRequested',
        amount,
        label: 'Demande de retrait',
        isCredit: false,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'withdrawal.requested',
      entityType: 'withdrawal',
      entityId: withdrawal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        amount,
        reference: withdrawal.reference,
      },
      transaction,
    });

    return serializeWithdrawal(withdrawal);
  });
}

async function cancelWithdrawal(userId, withdrawalId, requestContext = {}) {
  return sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findOne({
      where: { id: withdrawalId, userId },
      transaction,
    });
    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError("Ce retrait ne peut plus etre annule.", 409);
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) + Number(withdrawal.amount),
        reservedWithdrawalBalance:
          Number(wallet.reservedWithdrawalBalance) - Number(withdrawal.amount),
      },
      { transaction },
    );

    await withdrawal.update(
      {
        status: 'cancelled',
        cancelledAt: new Date(),
      },
      { transaction },
    );

    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'withdrawalReleased',
        amount: withdrawal.amount,
        label: 'Annulation retrait',
        isCredit: true,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'withdrawal.cancelled',
      entityType: 'withdrawal',
      entityId: withdrawal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        amount: Number(withdrawal.amount),
        reference: withdrawal.reference,
      },
      transaction,
    });

    return serializeWithdrawal(withdrawal);
  });
}

async function searchPendingWithdrawalByReference(reference) {
  const normalizedReference = String(reference || '').trim();
  if (!normalizedReference) {
    throw new AppError('La reference du retrait est requise.', 422);
  }

  const withdrawal = await models.Withdrawal.findOne({
    where: { reference: normalizedReference, status: 'requested' },
    include: [{ model: models.User, as: 'user' }],
  });
  if (!withdrawal) {
    throw new AppError('Retrait introuvable ou deja traite.', 404);
  }

  return {
    id: withdrawal.id,
    reference: withdrawal.reference,
    amount: Number(withdrawal.amount),
    status: withdrawal.status,
    requestedAt: withdrawal.requestedAt,
    client: {
      id: withdrawal.user.id,
      displayName: withdrawal.user.displayName,
      phoneNumber: displayPhone(withdrawal.user.phoneNumber),
    },
  };
}

async function payWithdrawal(agentProfile, withdrawalId, requestContext = {}) {
  return sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findOne({
      where: { id: withdrawalId },
      include: [{ model: models.User, as: 'user' }],
      transaction,
    });
    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError("Ce retrait n'est plus disponible pour paiement.", 409);
    }

    const wallet = await models.Wallet.findOne({
      where: { userId: withdrawal.userId },
      transaction,
    });

    const reserveConsumption = await consumeWithdrawalCommissionReserves({
      transaction,
      clientId: withdrawal.userId,
      withdrawalId: withdrawal.id,
      withdrawalAmount: Number(withdrawal.amount),
      agentProfileId: agentProfile.id,
      initiatedByUserId: agentProfile.userId,
      initiatorType: 'agent',
    });

    const commissionPosting = await postWithdrawalCommissions({
      transaction,
      clientId: withdrawal.userId,
      withdrawalId: withdrawal.id,
      sourceType: 'withdrawal',
      sourceId: withdrawal.id,
      agentProfileId: agentProfile.id,
      consumptions: reserveConsumption.consumptions,
      initiatedByUserId: agentProfile.userId,
      initiatorType: 'agent',
      requestContext,
    });

    await wallet.update(
      {
        reservedWithdrawalBalance:
          Number(wallet.reservedWithdrawalBalance) - Number(withdrawal.amount),
      },
      { transaction },
    );

    await withdrawal.update(
      {
        status: 'paid',
        paidAt: new Date(),
        paidByAgentProfileId: agentProfile.id,
      },
      { transaction },
    );

    await models.AvailableBalanceHistory.create(
      {
        userId: withdrawal.userId,
        type: 'withdrawalPaid',
        amount: withdrawal.amount,
        label: 'Retrait paye',
        isCredit: false,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'withdrawal.paid',
      entityType: 'withdrawal',
      entityId: withdrawal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        amount: Number(withdrawal.amount),
        reference: withdrawal.reference,
        reserveCovered: reserveConsumption.fullyCovered,
        uncoveredAmount: reserveConsumption.remainingPrincipal,
        agentCommissionAmount: commissionPosting.agentCommissionAmount,
        platformCommissionAmount: commissionPosting.platformCommissionAmount,
      },
      transaction,
    });

    return {
      ...serializeWithdrawal(withdrawal),
      commission: {
        agent: commissionPosting.agentCommissionAmount,
        platform: commissionPosting.platformCommissionAmount,
        uncoveredPrincipal: reserveConsumption.remainingPrincipal,
      },
    };
  });
}

module.exports = {
  listClientWithdrawals,
  createWithdrawal,
  cancelWithdrawal,
  searchPendingWithdrawalByReference,
  payWithdrawal,
};
