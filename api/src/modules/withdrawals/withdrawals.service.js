const crypto = require('crypto');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const { applyAgentBalanceChange } = require('../agent-cash/agent-cash.service');

const WITHDRAWAL_CONFIRMATION_TTL_MINUTES = 15;
const WITHDRAWAL_CONFIRMATION_MAX_ATTEMPTS = 5;

function generateWithdrawalReference() {
  return `WDR-${Date.now()}-${Math.floor(Math.random() * 9000)
    .toString()
    .padStart(4, '0')}`;
}

function generateConfirmationCode() {
  return `${Math.floor(100000 + Math.random() * 900000)}`;
}

function hashConfirmationCode(code) {
  return crypto
    .createHash('sha256')
    .update(String(code).trim())
    .digest('hex');
}

function computeConfirmationCodeExpiresAt() {
  const expiresAt = new Date();
  expiresAt.setMinutes(
    expiresAt.getMinutes() + WITHDRAWAL_CONFIRMATION_TTL_MINUTES,
  );
  return expiresAt;
}

function isConfirmationCodeExpired(withdrawal) {
  return Boolean(
    withdrawal.confirmationCodeExpiresAt &&
      new Date(withdrawal.confirmationCodeExpiresAt) < new Date(),
  );
}

function serializeWithdrawal(withdrawal, extras = {}) {
  return {
    id: withdrawal.id,
    reference: withdrawal.reference,
    amount: Number(withdrawal.amount),
    status: withdrawal.status,
    channel: withdrawal.channel,
    requestedAt: withdrawal.requestedAt,
    paidAt: withdrawal.paidAt,
    cancelledAt: withdrawal.cancelledAt,
    cancellationReason: withdrawal.cancellationReason,
    confirmationCodeExpiresAt: withdrawal.confirmationCodeExpiresAt,
    isConfirmationCodeExpired: isConfirmationCodeExpired(withdrawal),
    ...extras,
  };
}

async function releaseRequestedWithdrawal(
  withdrawal,
  {
    reason,
    notificationTitle,
    notificationMessage,
    auditAction,
    requestContext = {},
  },
  transaction,
) {
  const wallet = await models.Wallet.findOne({
    where: { userId: withdrawal.userId },
    transaction,
    lock: transaction.LOCK.UPDATE,
  });

  const amount = Number(withdrawal.amount);
  await wallet.update(
    {
      availableBalance: Number(wallet.availableBalance || 0) + amount,
      reservedWithdrawalBalance: Math.max(
        Number(wallet.reservedWithdrawalBalance || 0) - amount,
        0,
      ),
    },
    { transaction },
  );

  await withdrawal.update(
    {
      status: 'cancelled',
      cancelledAt: new Date(),
      cancellationReason: reason,
    },
    { transaction },
  );

  await models.AvailableBalanceHistory.create(
    {
      userId: withdrawal.userId,
      type: 'withdrawalCancelled',
      amount,
      label: `Retrait annule ${withdrawal.reference}`,
      isCredit: true,
    },
    { transaction },
  );

  await models.Notification.create(
    {
      userId: withdrawal.userId,
      type: 'system',
      title: notificationTitle,
      message: notificationMessage,
    },
    { transaction },
  );

  await writeAuditLog({
    userId: requestContext.initiatedByUserId || withdrawal.userId,
    action: auditAction,
    entityType: 'withdrawal',
    entityId: withdrawal.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      reference: withdrawal.reference,
      amount,
      reason,
    },
    transaction,
  });
}

async function listWithdrawals(userId) {
  const withdrawals = await models.Withdrawal.findAll({
    where: { userId },
    order: [['createdAt', 'DESC']],
    limit: 50,
  });

  return withdrawals.map((item) => serializeWithdrawal(item));
}

async function createWithdrawal(userId, payload, requestContext = {}) {
  const amount = Number(payload.amount);

  if (!amount || amount <= 0 || amount % 500 !== 0) {
    throw new AppError('Le retrait doit etre un multiple positif de 500.', 422);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const confirmationCode = generateConfirmationCode();
    const confirmationCodeExpiresAt = computeConfirmationCodeExpiresAt();
    const wallet = await models.Wallet.findOne({
      where: { userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!wallet) {
      throw new AppError('Portefeuille introuvable.', 404);
    }

    const availableBalance = Number(wallet.availableBalance || 0);
    if (availableBalance < amount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    const created = await models.Withdrawal.create(
      {
        reference: generateWithdrawalReference(),
        userId,
        amount,
        status: 'requested',
        channel: 'agent_cash',
        requestedAt: new Date(),
        confirmationCodeHash: hashConfirmationCode(confirmationCode),
        confirmationCodeExpiresAt,
        confirmationCodeAttempts: 0,
        initiatedByUserId: requestContext.initiatedByUserId || userId,
        initiatorType: requestContext.initiatorType || 'client',
      },
      { transaction },
    );

    await wallet.update(
      {
        availableBalance: availableBalance - amount,
        reservedWithdrawalBalance:
          Number(wallet.reservedWithdrawalBalance || 0) + amount,
      },
      { transaction },
    );

    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'withdrawalRequested',
        amount,
        label: `Retrait demande ${created.reference}`,
        isCredit: false,
      },
      { transaction },
    );

    await models.Notification.create(
      {
        userId,
        type: 'system',
        title: 'Retrait demande',
        message: `${amount} F reserves. Reference ${created.reference}. Code de validation genere.`,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'withdrawal.requested',
      entityType: 'withdrawal',
      entityId: created.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        amount,
        reference: created.reference,
        confirmationCodeExpiresAt,
      },
      transaction,
    });

    return {
      withdrawal: created,
      confirmationCode,
      confirmationCodeExpiresAt,
    };
  });

  return serializeWithdrawal(result.withdrawal, {
    confirmationCode: result.confirmationCode,
    confirmationCodeExpiresAt: result.confirmationCodeExpiresAt,
  });
}

async function cancelWithdrawal(userId, withdrawalId, payload, requestContext = {}) {
  const cancellationReason = payload.reason
    ? String(payload.reason).trim()
    : 'Annulation client';

  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findOne({
      where: { id: withdrawalId, userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError("Seul un retrait en attente peut etre annule.", 409);
    }
    await releaseRequestedWithdrawal(
      withdrawal,
      {
        reason: cancellationReason,
        notificationTitle: 'Retrait annule',
        notificationMessage:
          '${Number(withdrawal.amount)} F restitues a votre solde disponible.',
        auditAction: 'withdrawal.cancelled',
        requestContext,
      },
      transaction,
    );

    return withdrawal;
  });

  return serializeWithdrawal(result);
}

async function regenerateWithdrawalCode(userId, withdrawalId, requestContext = {}) {
  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findOne({
      where: { id: withdrawalId, userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError(
        "Seul un retrait en attente peut recevoir un nouveau code.",
        409,
      );
    }
    if (!isConfirmationCodeExpired(withdrawal)) {
      throw new AppError(
        'Le code actuel est encore valide. Utilisez-le ou attendez son expiration.',
        409,
      );
    }

    const confirmationCode = generateConfirmationCode();
    const confirmationCodeExpiresAt = computeConfirmationCodeExpiresAt();

    await withdrawal.update(
      {
        confirmationCodeHash: hashConfirmationCode(confirmationCode),
        confirmationCodeExpiresAt,
        confirmationCodeAttempts: 0,
      },
      { transaction },
    );

    await models.Notification.create(
      {
        userId,
        type: 'system',
        title: 'Nouveau code de retrait',
        message: `Un nouveau code de validation a ete genere pour le retrait ${withdrawal.reference}.`,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'withdrawal.confirmation_code_regenerated',
      entityType: 'withdrawal',
      entityId: withdrawal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: withdrawal.reference,
        confirmationCodeExpiresAt,
      },
      transaction,
    });

    return {
      withdrawal,
      confirmationCode,
      confirmationCodeExpiresAt,
    };
  });

  return serializeWithdrawal(result.withdrawal, {
    confirmationCode: result.confirmationCode,
    confirmationCodeExpiresAt: result.confirmationCodeExpiresAt,
  });
}

async function findPendingWithdrawalByReference(reference) {
  const normalizedReference = String(reference || '').trim().toUpperCase();
  if (!normalizedReference) {
    throw new AppError('La reference du retrait est requise.', 422);
  }

  const withdrawal = await sequelize.transaction(async (transaction) => {
    const pendingWithdrawal = await models.Withdrawal.findOne({
      where: {
        reference: normalizedReference,
        status: 'requested',
      },
      include: [{ model: models.User, as: 'user' }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!pendingWithdrawal) {
      throw new AppError('Aucun retrait en attente pour cette reference.', 404);
    }

    return pendingWithdrawal;
  });

  return serializeWithdrawal(withdrawal, {
    client: withdrawal.user
      ? {
          id: withdrawal.user.id,
          displayName: withdrawal.user.displayName,
          phoneNumber: displayPhone(withdrawal.user.phoneNumber),
        }
      : null,
  });
}

async function payWithdrawal(
  agentProfile,
  withdrawalId,
  payload,
  requestContext = {},
) {
  const confirmationCode = String(payload.confirmationCode || '').trim();
  if (confirmationCode.length < 4) {
    throw new AppError('Le code de confirmation est requis.', 422);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
      include: [{ model: models.User, as: 'user' }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError("Ce retrait n'est plus en attente.", 409);
    }
    if (isConfirmationCodeExpired(withdrawal)) {
      await writeAuditLog({
        userId: agentProfile.userId,
        action: 'withdrawal.payment_attempt_with_expired_code',
        entityType: 'withdrawal',
        entityId: withdrawal.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          reference: withdrawal.reference,
        },
        transaction,
      });
      throw new AppError(
        "Le code de confirmation a expire. Demandez au client d'en generer un nouveau.",
        409,
      );
    }
    if (
      Number(withdrawal.confirmationCodeAttempts || 0) >=
      WITHDRAWAL_CONFIRMATION_MAX_ATTEMPTS
    ) {
      await releaseRequestedWithdrawal(
        withdrawal,
        {
          reason: 'Trop de codes de confirmation invalides',
          notificationTitle: 'Retrait annule',
          notificationMessage:
            'Le retrait a ete annule apres plusieurs codes invalides. Le montant est revenu dans votre solde disponible.',
          auditAction: 'withdrawal.cancelled_after_invalid_confirmations',
          requestContext,
        },
        transaction,
      );
      throw new AppError(
        'Ce retrait a ete annule apres trop de tentatives. Le client doit refaire sa demande.',
        422,
      );
    }

    const receivedCodeHash = hashConfirmationCode(confirmationCode);
    if (receivedCodeHash !== withdrawal.confirmationCodeHash) {
      const nextAttempts = Number(withdrawal.confirmationCodeAttempts || 0) + 1;
      if (nextAttempts >= WITHDRAWAL_CONFIRMATION_MAX_ATTEMPTS) {
        await releaseRequestedWithdrawal(
          withdrawal,
          {
            reason: 'Trop de codes de confirmation invalides',
            notificationTitle: 'Retrait annule',
            notificationMessage:
              'Le retrait a ete annule apres plusieurs codes invalides. Le montant est revenu dans votre solde disponible.',
            auditAction: 'withdrawal.cancelled_after_invalid_confirmations',
            requestContext,
          },
          transaction,
        );
      } else {
        await withdrawal.update(
          {
            confirmationCodeAttempts: nextAttempts,
          },
          { transaction },
        );
      }

      await writeAuditLog({
        userId: agentProfile.userId,
        action: 'withdrawal.payment_confirmation_failed',
        entityType: 'withdrawal',
        entityId: withdrawal.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          reference: withdrawal.reference,
          attempts: nextAttempts,
          autoCancelled: nextAttempts >= WITHDRAWAL_CONFIRMATION_MAX_ATTEMPTS,
        },
        transaction,
      });

      throw new AppError(
        nextAttempts >= WITHDRAWAL_CONFIRMATION_MAX_ATTEMPTS
          ? 'Trop de codes invalides. Le retrait a ete annule et le client doit refaire sa demande.'
          : 'Code de confirmation invalide.',
        422,
      );
    }

    const wallet = await models.Wallet.findOne({
      where: { userId: withdrawal.userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    const amount = Number(withdrawal.amount);
    const reservedBalance = Number(wallet?.reservedWithdrawalBalance || 0);
    if (reservedBalance < amount) {
      throw new AppError(
        'Le solde reserve du client est incoherent pour ce retrait.',
        409,
      );
    }

    await wallet.update(
      {
        reservedWithdrawalBalance: reservedBalance - amount,
      },
      { transaction },
    );

    await withdrawal.update(
      {
        status: 'paid',
        paidAt: new Date(),
        paidByUserId: agentProfile.userId,
        confirmationCodeAttempts: Number(withdrawal.confirmationCodeAttempts || 0),
      },
      { transaction },
    );

    const cashChange = await applyAgentBalanceChange(
      agentProfile.id,
      {
        amount,
        isCredit: true,
        type: 'clientWithdrawal',
        label: `Retrait client ${withdrawal.user?.displayName || ''}`.trim(),
        note: `Paiement retrait ${withdrawal.reference}`,
        relatedEntityType: 'withdrawal',
        relatedEntityId: withdrawal.id,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'agent.cash_credited_from_client_withdrawal',
        reference: withdrawal.reference,
      },
      transaction,
    );

    await models.Notification.create(
      {
        userId: withdrawal.userId,
        type: 'system',
        title: 'Retrait paye',
        message: `${amount} F retires avec succes aupres d'un agent.`,
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
        reference: withdrawal.reference,
        amount,
        agentBalanceAfter: cashChange.balanceAfter,
      },
      transaction,
    });

    return {
      withdrawal,
      agentBalance: cashChange.balanceAfter,
    };
  });

  return serializeWithdrawal(result.withdrawal, {
    agentBalance: result.agentBalance,
  });
}

module.exports = {
  listWithdrawals,
  createWithdrawal,
  cancelWithdrawal,
  regenerateWithdrawalCode,
  findPendingWithdrawalByReference,
  payWithdrawal,
};
