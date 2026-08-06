const fs = require('fs/promises');
const crypto = require('crypto');
const path = require('path');
const AppError = require('../../common/errors/app-error');
const {
  FINANCIAL_AMOUNT_STEP,
} = require('../../common/constants/finance');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const env = require('../../config/env');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const { applyAgentBalanceChange } = require('../agent-cash/agent-cash.service');
const {
  consumeWithdrawalCommissionReserves,
  postWithdrawalCommissions,
} = require('../commission/commission.service');
const {
  getActiveGroupDebtForUser,
  getClientFinancialSnapshot,
} = require('../agent-groups/agent-group-capacity.service');
const {
  assertPaymentMethodEnabled,
} = require('../payment-methods/payment-methods.service');

const WITHDRAWAL_CONFIRMATION_TTL_MINUTES = 15;
const WITHDRAWAL_CONFIRMATION_MAX_ATTEMPTS = 5;
const AGENT_CASH_CHANNEL = 'agent_cash';
const ADMIN_REVIEW_CHANNELS = new Set(['mobile_money', 'bank_transfer']);

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
    .update(String(code || '').trim())
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

function normalizeWithdrawalChannel(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) {
    return AGENT_CASH_CHANNEL;
  }

  if (!['agent_cash', 'mobile_money', 'bank_transfer'].includes(normalized)) {
    throw new AppError('La methode de retrait selectionnee est invalide.', 422);
  }

  return normalized;
}

function isAgentCashWithdrawal(withdrawal) {
  return String(withdrawal?.channel || '').trim() === AGENT_CASH_CHANNEL;
}

function buildWithdrawalProofUploadUrl(fileName) {
  return `${String(env.appBaseUrl || '').replace(/\/+$/, '')}/uploads/withdrawals/${fileName}`;
}

function normalizeWithdrawalProofUrl(value) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    return '';
  }

  if (!/^(https?:\/\/|\/uploads\/withdrawals\/)/i.test(normalized)) {
    throw new AppError(
      "L'URL de la preuve de paiement est invalide.",
      422,
    );
  }

  return normalized;
}

async function persistWithdrawalProofImage(payload = {}) {
  const imageBase64 = String(
    payload.paymentProofImageBase64 || payload.imageBase64 || '',
  ).trim();
  if (!imageBase64) {
    return null;
  }

  const imageMimeType = String(
    payload.paymentProofImageMimeType || payload.imageMimeType || '',
  )
    .trim()
    .toLowerCase();
  const allowedMimeTypes = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  const extension = allowedMimeTypes[imageMimeType];
  if (!extension) {
    throw new AppError(
      "Le format d'image de la preuve doit etre JPG, PNG ou WEBP.",
      422,
    );
  }

  const normalizedBase64 = imageBase64.includes('base64,')
    ? imageBase64.split('base64,').pop()
    : imageBase64;
  const buffer = Buffer.from(normalizedBase64, 'base64');
  if (!buffer.length) {
    throw new AppError("L'image de la preuve de paiement est vide.", 422);
  }
  if (buffer.length > 5 * 1024 * 1024) {
    throw new AppError(
      "L'image de la preuve de paiement ne doit pas depasser 5 Mo.",
      422,
    );
  }

  const uploadDirectory = path.join(
    __dirname,
    '..',
    '..',
    'public',
    'uploads',
    'withdrawals',
  );
  await fs.mkdir(uploadDirectory, { recursive: true });

  const fileName = `withdrawal-proof-${Date.now()}-${crypto.randomBytes(6).toString('hex')}.${extension}`;
  await fs.writeFile(path.join(uploadDirectory, fileName), buffer);

  return buildWithdrawalProofUploadUrl(fileName);
}

function serializeWithdrawal(withdrawal, extras = {}) {
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
    approvedAt: withdrawal.approvedAt,
    approvedByAdminUsername: withdrawal.approvedByAdminUsername || null,
    paidAt: withdrawal.paidAt,
    paidByAdminUsername: withdrawal.paidByAdminUsername || null,
    cancelledAt: withdrawal.cancelledAt,
    rejectedAt: withdrawal.rejectedAt,
    paymentReference: withdrawal.paymentReference || null,
    paymentProofImageUrl: withdrawal.paymentProofImageUrl || null,
    paymentProofUploadedAt: withdrawal.paymentProofUploadedAt || null,
    notes: withdrawal.notes,
    cancellationReason: withdrawal.cancellationReason,
    rejectionReason: withdrawal.rejectionReason,
    confirmationCodeExpiresAt: withdrawal.confirmationCodeExpiresAt,
    isConfirmationCodeExpired: isConfirmationCodeExpired(withdrawal),
    requiresConfirmationCode:
      isAgentCashWithdrawal(withdrawal) && withdrawal.status === 'requested',
    requiresAdminReview:
      !isAgentCashWithdrawal(withdrawal) && withdrawal.status === 'requested',
    payingAgent: withdrawal.payingAgent
      ? {
          id: withdrawal.payingAgent.id,
          agentCode: withdrawal.payingAgent.agentCode,
          fullName: withdrawal.payingAgent.fullName,
        }
      : null,
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
    finalStatus = 'cancelled',
    timestampField = 'cancelledAt',
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
      status: finalStatus,
      [timestampField]: new Date(),
      cancellationReason:
        finalStatus === 'cancelled' ? reason : withdrawal.cancellationReason,
      rejectionReason:
        finalStatus === 'rejected' ? reason : withdrawal.rejectionReason,
    },
    { transaction },
  );

  await models.AvailableBalanceHistory.create(
    {
      userId: withdrawal.userId,
      type: 'withdrawalReleased',
      amount,
      label:
        finalStatus === 'rejected'
          ? `Retrait refuse ${withdrawal.reference}`
          : `Retrait annule ${withdrawal.reference}`,
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
      finalStatus,
    },
    transaction,
  });
}

async function listClientWithdrawals(userId) {
  const withdrawals = await models.Withdrawal.findAll({
    where: { userId },
    include: [{ model: models.AgentProfile, as: 'payingAgent', required: false }],
    order: [['createdAt', 'DESC']],
    limit: 50,
  });

  return withdrawals.map((item) => serializeWithdrawal(item));
}

async function createWithdrawal(userId, payload, requestContext = {}) {
  const amount = Number(payload?.amount);
  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `Le montant du retrait doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }
  const channel = normalizeWithdrawalChannel(
    payload?.channel || payload?.withdrawalMethod,
  );
  const requiresAdminReview = ADMIN_REVIEW_CHANNELS.has(channel);
  await assertPaymentMethodEnabled(
    channel,
    'withdrawal',
    'Cette methode de retrait est temporairement indisponible.',
  );

  const result = await sequelize.transaction(async (transaction) => {
    const wallet = await models.Wallet.findOne({
      where: { userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!wallet) {
      throw new AppError('Portefeuille introuvable.', 404);
    }
    if (Number(wallet.availableBalance || 0) < amount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    const financialSnapshot = await getClientFinancialSnapshot(userId, transaction);
    const activeGroupDebt = await getActiveGroupDebtForUser(userId, {
      transaction,
    });
    const estimatedCapacityAfterWithdrawal = Math.max(
      financialSnapshot.estimatedCapacity - amount,
      0,
    );

    if (estimatedCapacityAfterWithdrawal < activeGroupDebt) {
      throw new AppError(
        'Retrait indisponible car il reduirait votre capacite a honorer vos cotisations de groupe en cours.',
        422,
      );
    }

    const confirmationCode = generateConfirmationCode();
    const confirmationCodeExpiresAt = computeConfirmationCodeExpiresAt();
    const withdrawal = await models.Withdrawal.create(
      {
        reference: generateWithdrawalReference(),
        userId,
        amount,
        status: 'requested',
        channel,
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
        availableBalance: Number(wallet.availableBalance || 0) - amount,
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
        label: `Retrait demande ${withdrawal.reference}`,
        isCredit: false,
      },
      { transaction },
    );

    await models.Notification.create(
      {
        userId,
        type: 'system',
        title: requiresAdminReview
          ? 'Demande de retrait en attente'
          : 'Retrait demande',
        message: requiresAdminReview
          ? `${amount} F reserves. Reference ${withdrawal.reference}. La demande sera verifiee par l'administration.`
          : `${amount} F reserves. Reference ${withdrawal.reference}. Code de validation genere.`,
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
        confirmationCodeExpiresAt,
        channel,
        requiresAdminReview,
      },
      transaction,
    });

    return {
      withdrawal,
      confirmationCode: requiresAdminReview ? null : confirmationCode,
      confirmationCodeExpiresAt,
      requiresConfirmationCode: !requiresAdminReview,
      requiresAdminReview,
    };
  });

  return serializeWithdrawal(result.withdrawal, {
    confirmationCode: result.confirmationCode,
    confirmationCodeExpiresAt: result.requiresConfirmationCode
      ? result.confirmationCodeExpiresAt
      : null,
    requiresConfirmationCode: result.requiresConfirmationCode,
    requiresAdminReview: result.requiresAdminReview,
  });
}

async function cancelWithdrawal(
  userId,
  withdrawalId,
  payload = {},
  requestContext = {},
) {
  const cancellationReason = payload?.reason
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
        notificationMessage: `${Number(withdrawal.amount)} F restitues a votre solde disponible.`,
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
    if (!isAgentCashWithdrawal(withdrawal)) {
      throw new AppError(
        'Cette demande de retrait ne requiert pas de code de confirmation.',
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

  const withdrawal = await models.Withdrawal.findOne({
    where: {
      reference: normalizedReference,
      status: 'requested',
      channel: AGENT_CASH_CHANNEL,
    },
    include: [{ model: models.User, as: 'user' }],
  });

  if (!withdrawal) {
    throw new AppError('Aucun retrait en attente pour cette reference.', 404);
  }

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
  payload = {},
  requestContext = {},
) {
  const confirmationCode = String(payload?.confirmationCode || '').trim();
  if (confirmationCode.length < 4) {
    throw new AppError('Le code de confirmation est requis.', 422);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
      include: [
        { model: models.User, as: 'user' },
        { model: models.AgentProfile, as: 'payingAgent', required: false },
      ],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError("Ce retrait n'est plus en attente.", 409);
    }
    if (!isAgentCashWithdrawal(withdrawal)) {
      throw new AppError(
        "Ce retrait doit etre traite par l'administration.",
        409,
      );
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
    if (!wallet || reservedBalance < amount) {
      throw new AppError(
        'Le solde reserve du client est incoherent pour ce retrait.',
        409,
      );
    }

    const reserveConsumption = await consumeWithdrawalCommissionReserves({
      transaction,
      clientId: withdrawal.userId,
      withdrawalId: withdrawal.id,
      withdrawalAmount: amount,
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
        reservedWithdrawalBalance: reservedBalance - amount,
      },
      { transaction },
    );

    await withdrawal.update(
      {
        status: 'paid',
        paidAt: new Date(),
        paidByAgentProfileId: agentProfile.id,
        paidByAdminUsername: null,
        confirmationCodeAttempts: Number(
          withdrawal.confirmationCodeAttempts || 0,
        ),
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

    await models.AvailableBalanceHistory.create(
      {
        userId: withdrawal.userId,
        type: 'withdrawalPaid',
        amount,
        label: `Retrait paye ${withdrawal.reference}`,
        isCredit: false,
      },
      { transaction },
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
        amount,
        reference: withdrawal.reference,
        reserveCovered: reserveConsumption.fullyCovered,
        uncoveredAmount: reserveConsumption.remainingPrincipal,
        agentCommissionAmount: commissionPosting.agentCommissionAmount,
        platformCommissionAmount: commissionPosting.platformCommissionAmount,
        agentBalanceAfter: cashChange.balanceAfter,
      },
      transaction,
    });

    return {
      withdrawal,
      agentBalance: cashChange.balanceAfter,
      commission: {
        agent: commissionPosting.agentCommissionAmount,
        platform: commissionPosting.platformCommissionAmount,
        uncoveredPrincipal: reserveConsumption.remainingPrincipal,
      },
    };
  });

  return serializeWithdrawal(result.withdrawal, {
    agentBalance: result.agentBalance,
    commission: result.commission,
  });
}

async function approveWithdrawalByAdmin(
  withdrawalId,
  payload = {},
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
      include: [{ model: models.User, as: 'user', required: true }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError('Seul un retrait en attente peut etre approuve.', 409);
    }
    if (isAgentCashWithdrawal(withdrawal)) {
      throw new AppError(
        'Ce retrait suit le workflow agent et ne peut pas etre approuve par l\'administration.',
        409,
      );
    }

    await withdrawal.update(
      {
        status: 'approved',
        approvedAt: new Date(),
        approvedByAdminUsername: requestContext.adminUsername || null,
        notes: payload?.note ? String(payload.note).trim() : withdrawal.notes,
      },
      { transaction },
    );

    await models.Notification.create(
      {
        userId: withdrawal.userId,
        type: 'system',
        title: 'Retrait approuve',
        message: `Votre demande de retrait ${withdrawal.reference} a ete approuvee. Le transfert sera effectue sous peu.`,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: null,
      action: 'withdrawal.approved',
      entityType: 'withdrawal',
      entityId: withdrawal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        reference: withdrawal.reference,
        amount: Number(withdrawal.amount),
        channel: withdrawal.channel,
        note: payload?.note ? String(payload.note).trim() : null,
      },
      transaction,
    });

    return withdrawal;
  });

  return serializeWithdrawal(result);
}

async function rejectWithdrawalByAdmin(
  withdrawalId,
  payload = {},
  requestContext = {},
) {
  const reason = String(payload?.reason || payload?.note || '').trim();
  if (!reason) {
    throw new AppError('Le motif de refus est requis.', 422);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
      include: [{ model: models.User, as: 'user', required: true }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'requested') {
      throw new AppError('Seul un retrait en attente peut etre refuse.', 409);
    }
    if (isAgentCashWithdrawal(withdrawal)) {
      throw new AppError(
        'Ce retrait suit le workflow agent et ne peut pas etre refuse par l\'administration.',
        409,
      );
    }

    await releaseRequestedWithdrawal(
      withdrawal,
      {
        reason,
        notificationTitle: 'Retrait refuse',
        notificationMessage: `Votre demande de retrait ${withdrawal.reference} a ete refusee. Motif: ${reason}.`,
        auditAction: 'withdrawal.rejected',
        requestContext,
        finalStatus: 'rejected',
        timestampField: 'rejectedAt',
      },
      transaction,
    );

    return withdrawal;
  });

  return serializeWithdrawal(result);
}

async function persistWithdrawalPayment(
  withdrawal,
  payload = {},
  requestContext = {},
  transaction,
) {
  const paymentReference = String(payload?.paymentReference || '').trim();
  if (!paymentReference) {
    throw new AppError('La reference de paiement est requise.', 422);
  }

  const wallet = await models.Wallet.findOne({
    where: { userId: withdrawal.userId },
    transaction,
    lock: transaction.LOCK.UPDATE,
  });

  const amount = Number(withdrawal.amount);
  const reservedBalance = Number(wallet?.reservedWithdrawalBalance || 0);
  if (!wallet || reservedBalance < amount) {
    throw new AppError(
      'Le solde reserve du client est incoherent pour ce retrait.',
      409,
    );
  }

  const paymentProofImageUrl =
    (await persistWithdrawalProofImage(payload)) ||
    normalizeWithdrawalProofUrl(payload.paymentProofImageUrl);

  if (!paymentProofImageUrl) {
    throw new AppError('La preuve image de paiement est requise.', 422);
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
      paidByAdminUsername: requestContext.adminUsername || null,
      paymentReference,
      paymentProofImageUrl,
      paymentProofUploadedAt: new Date(),
      notes: payload?.note ? String(payload.note).trim() : withdrawal.notes,
    },
    { transaction },
  );

  await models.AvailableBalanceHistory.create(
    {
      userId: withdrawal.userId,
      type: 'withdrawalPaid',
      amount,
      label: `Retrait paye ${withdrawal.reference}`,
      isCredit: false,
    },
    { transaction },
  );

  await models.Notification.create(
    {
      userId: withdrawal.userId,
      type: 'system',
      title: 'Retrait paye',
      message: `Votre retrait ${withdrawal.reference} a ete paye. Reference: ${paymentReference}.`,
    },
    { transaction },
  );

  await writeAuditLog({
    userId: null,
    action: 'withdrawal.admin_paid',
    entityType: 'withdrawal',
    entityId: withdrawal.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      adminUsername: requestContext.adminUsername || null,
      amount,
      reference: withdrawal.reference,
      paymentReference,
      paymentProofImageUrl,
      channel: withdrawal.channel,
    },
    transaction,
  });

  return withdrawal;
}

async function markWithdrawalPaidByAdmin(
  withdrawalId,
  payload = {},
  requestContext = {},
) {
  const result = await sequelize.transaction(async (transaction) => {
    const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
      include: [{ model: models.User, as: 'user', required: true }],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!withdrawal) {
      throw new AppError('Retrait introuvable.', 404);
    }
    if (withdrawal.status !== 'approved') {
      throw new AppError('Seul un retrait approuve peut etre marque paye.', 409);
    }
    if (isAgentCashWithdrawal(withdrawal)) {
      throw new AppError(
        'Ce retrait suit le workflow agent et ne peut pas etre marque paye par l\'administration.',
        409,
      );
    }

    await persistWithdrawalPayment(
      withdrawal,
      payload,
      requestContext,
      transaction,
    );

    return withdrawal;
  });

  return serializeWithdrawal(result);
}

module.exports = {
  listClientWithdrawals,
  createWithdrawal,
  cancelWithdrawal,
  regenerateWithdrawalCode,
  findPendingWithdrawalByReference,
  payWithdrawal,
  approveWithdrawalByAdmin,
  rejectWithdrawalByAdmin,
  markWithdrawalPaidByAdmin,
};
