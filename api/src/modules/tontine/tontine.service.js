const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const {
  FINANCIAL_AMOUNT_STEP,
} = require('../../common/constants/finance');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const {
  createCycleCommissionSnapshot,
  createWithdrawalReserve,
  postDepositCommissions,
  reverseCommissionCredits,
} = require('../commission/commission.service');

function ensureStakeMultiple(stakeAmount) {
  if (
    !stakeAmount ||
    stakeAmount <= 0 ||
    stakeAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `La mise doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }
}

function computeExpectedEndAt(startDate) {
  const expectedEndAt = new Date(startDate);
  expectedEndAt.setDate(expectedEndAt.getDate() + 30);
  return expectedEndAt;
}

function serializeCycle(cycle) {
  if (!cycle) {
    return null;
  }
  const stakeAmount = Number(cycle.stakeAmount);
  const cumulativeAmount = Number(cycle.cumulativeAmount);
  return {
    id: cycle.id,
    stakeAmount,
    cumulativeAmount,
    status: cycle.status,
    targetAmount: stakeAmount * 31,
    netPayoutAmount: stakeAmount * 30,
    commissionAmount: stakeAmount,
    progress:
      stakeAmount > 0
        ? Math.min(cumulativeAmount / (stakeAmount * 31), 1)
        : 0,
    startedAt: cycle.startedAt,
    expectedEndAt: cycle.expectedEndAt,
    endedAt: cycle.endedAt,
  };
}

async function getLatestCycle(userId, transaction) {
  return models.TontineCycle.findOne({
    where: { userId },
    order: [['createdAt', 'DESC']],
    transaction,
  });
}

async function getOpenCycleForFunding(userId, transaction) {
  const cycle = await getLatestCycle(userId, transaction);
  if (!cycle || !['active', 'enAttenteValidationFin'].includes(cycle.status)) {
    throw new AppError('Aucune tontine active disponible.', 409);
  }

  const targetAmount = Number(cycle.stakeAmount) * 31;
  const cumulativeAmount = Number(cycle.cumulativeAmount);
  const remainingAmount = Math.max(targetAmount - cumulativeAmount, 0);

  return {
    cycle,
    targetAmount,
    cumulativeAmount,
    remainingAmount,
  };
}

async function appendNotification(transaction, userId, type, title, message) {
  await models.Notification.create(
    {
      userId,
      type,
      title,
      message,
    },
    { transaction },
  );
}

async function appendAvailableHistory(
  transaction,
  userId,
  type,
  amount,
  label,
  isCredit,
  extra = {},
) {
  return models.AvailableBalanceHistory.create(
    {
      userId,
      type,
      amount,
      label,
      isCredit,
      ...extra,
    },
    { transaction },
  );
}

async function appendCycleHistory(
  transaction,
  userId,
  cycleId,
  type,
  amount,
  label,
  note = null,
  actor = {},
  extra = {},
) {
  return models.TontineHistory.create(
    {
      userId,
      cycleId,
      type,
      amount,
      label,
      note,
      initiatedByUserId: actor.initiatedByUserId || null,
      initiatorType: actor.initiatorType || null,
      ...extra,
    },
    { transaction },
  );
}

function resolveActorForUser(userId, requestContext = {}) {
  const initiatorType = requestContext.initiatorType || 'client';
  return {
    initiatedByUserId:
      requestContext.initiatedByUserId ||
      (initiatorType === 'client' ? userId : null),
    initiatorType,
  };
}

function getExternalDepositSourceLabel(source) {
  switch (source) {
    case 'fedapay':
      return 'FedaPay';
    case 'mtn_momo':
      return 'MTN MoMo';
    case 'afrikmoney':
      return 'Afrikmoney';
    default:
      return 'les versements externes';
  }
}

function getDepositHistoryLabel(source) {
  switch (source) {
    case 'wallet':
      return 'Versement depuis disponible';
    case 'fedapay':
      return 'Versement FedaPay';
    case 'mtn_momo':
      return 'Versement MTN MoMo';
    case 'afrikmoney':
      return 'Versement Afrikmoney';
    default:
      return 'Versement tontine';
  }
}

function getDepositNotificationTitle(source) {
  switch (source) {
    case 'wallet':
      return 'Retour vers la tontine';
    case 'fedapay':
      return 'Paiement FedaPay';
    case 'mtn_momo':
      return 'Paiement MTN MoMo';
    case 'afrikmoney':
      return 'Paiement Afrikmoney';
    default:
      return 'Versement tontine';
  }
}

function getDepositNotificationMessage(source, amount) {
  switch (source) {
    case 'fedapay':
      return `${amount} F valides ont ete ajoutes a votre tontine via FedaPay.`;
    case 'mtn_momo':
      return `${amount} F valides ont ete ajoutes a votre tontine via MTN MoMo.`;
    case 'afrikmoney':
      return `${amount} F valides ont ete ajoutes a votre tontine via Afrikmoney.`;
    default:
      return `${amount} F ajoutes a votre tontine.`;
  }
}

async function findWalletFundingHistoryForDeposit(originalHistory, transaction) {
  if (originalHistory.availableBalanceHistoryId) {
    const linkedFundingHistory = await models.AvailableBalanceHistory.findOne({
      where: {
        id: originalHistory.availableBalanceHistoryId,
        userId: originalHistory.userId,
      },
      transaction,
    });

    if (linkedFundingHistory) {
      return linkedFundingHistory;
    }
  }

  const occurredAt = originalHistory.occurredAt
    ? new Date(originalHistory.occurredAt)
    : null;
  const timeWindow = occurredAt
    ? {
        [Op.between]: [
          new Date(occurredAt.getTime() - 5 * 60 * 1000),
          new Date(occurredAt.getTime() + 5 * 60 * 1000),
        ],
      }
    : undefined;

  return models.AvailableBalanceHistory.findOne({
    where: {
      userId: originalHistory.userId,
      type: 'tontineFunding',
      amount: Number(originalHistory.amount),
      isCredit: false,
      ...(timeWindow ? { occurredAt: timeWindow } : {}),
    },
    order: [['occurredAt', 'DESC']],
    transaction,
  });
}

async function reverseDepositCommissions({
  transaction,
  originalHistory,
  reason,
  requestContext = {},
}) {
  const candidateSourceIds = [];

  if (originalHistory.linkedProvisioningId) {
    candidateSourceIds.push(originalHistory.linkedProvisioningId);
  }

  if (originalHistory.initiatorType === 'agent' && !originalHistory.linkedProvisioningId) {
    const provisioning = await models.Provisioning.findOne({
      where: {
        clientUserId: originalHistory.userId,
        cycleId: originalHistory.cycleId,
        amount: Number(originalHistory.amount),
        status: 'validated',
      },
      order: [['validatedAt', 'DESC']],
      transaction,
    });

    if (provisioning) {
      candidateSourceIds.unshift(provisioning.id);
    }
  }

  candidateSourceIds.push(originalHistory.id);

  if (candidateSourceIds.length === 0) {
    candidateSourceIds.push(originalHistory.cycleId);
  }

  const uniqueSourceIds = [...new Set(candidateSourceIds.filter(Boolean))];
  for (const sourceId of uniqueSourceIds) {
    const commissionReversal = await reverseCommissionCredits({
      transaction,
      sourceType: 'tontine_deposit',
      sourceId,
      initiatedByUserId: requestContext.initiatedByUserId || null,
      initiatorType: requestContext.initiatorType || 'admin',
      reason,
      requestContext,
    });

    if (commissionReversal.reversedEntriesCount > 0) {
      return {
        ...commissionReversal,
        sourceId,
      };
    }
  }

  const depositCount = await models.TontineHistory.count({
    where: {
      cycleId: originalHistory.cycleId,
      type: 'deposit',
    },
    transaction,
  });

  if (depositCount === 1) {
    const cycleCommissionReversal = await reverseCommissionCredits({
      transaction,
      sourceType: 'tontine_deposit',
      sourceId: originalHistory.cycleId,
      initiatedByUserId: requestContext.initiatedByUserId || null,
      initiatorType: requestContext.initiatorType || 'admin',
      reason,
      requestContext,
    });

    if (cycleCommissionReversal.reversedEntriesCount > 0) {
      return {
        ...cycleCommissionReversal,
        sourceId: originalHistory.cycleId,
      };
    }
  }

  return {
    reversedEntriesCount: 0,
    totalReversedAmount: 0,
    reversalEntries: [],
    sourceId: uniqueSourceIds[0] || originalHistory.id || originalHistory.cycleId || null,
    skipped: true,
  };
}

async function configureStake(userId, stakeAmount, requestContext = {}) {
  ensureStakeMultiple(stakeAmount);
  return sequelize.transaction(async (transaction) => {
    const actor = resolveActorForUser(userId, requestContext);
    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    const startedAt = new Date();
    await models.TontineCycle.create(
      {
        userId,
        stakeAmount,
        cumulativeAmount: 0,
        status: 'active',
        startedAt,
        expectedEndAt: computeExpectedEndAt(startedAt),
      },
      { transaction },
    );
    await wallet.update({ tontineBalance: 0 }, { transaction });
    const cycle = await getLatestCycle(userId, transaction);
    await createCycleCommissionSnapshot({
      transaction,
      cycle,
      userId,
    });
    await appendCycleHistory(
      transaction,
      userId,
      cycle.id,
      'configuration',
      stakeAmount,
      'Mise configuree',
      `Mise ${Number(stakeAmount).toFixed(0)} F`,
      actor,
    );
    await writeAuditLog({
      userId,
      action: 'tontine.configured',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        stakeAmount: Number(stakeAmount),
      },
      transaction,
    });
    return serializeCycle(cycle);
  });
}

async function getCycleOverview(userId) {
  const cycle = await getLatestCycle(userId);
  const histories = await models.TontineHistory.findAll({
    where: {
      userId,
      cycleId: cycle?.id || null,
    },
    order: [['occurredAt', 'DESC']],
  });
  const archives = await models.TontineArchive.findAll({
    where: { userId },
    order: [['endedAt', 'DESC']],
  });
  return {
    cycle: serializeCycle(cycle),
    history: histories,
    archives,
  };
}

async function depositToCycle(
  userId,
  amount,
  source = 'external',
  requestContext = {},
) {
  const allowedSources = new Set([
    'wallet',
    'external',
    'fedapay',
    'mtn_momo',
    'afrikmoney',
  ]);
  if (!allowedSources.has(source)) {
    throw new AppError('Source de versement invalide.', 422);
  }

  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `Le versement doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }

  const executeDeposit = async (transaction) => {
    const actor = resolveActorForUser(userId, requestContext);
    if (
      (source === 'external' ||
        source === 'fedapay' ||
        source === 'mtn_momo' ||
        source === 'afrikmoney') &&
      actor.initiatorType === 'client'
    ) {
      throw new AppError(
        source === 'external'
          ? "Les versements externes ne sont plus autorises depuis l'application client. Utilisez votre solde disponible."
          : `Les versements ${getExternalDepositSourceLabel(source)} doivent passer par la confirmation du serveur.`,
        422,
      );
    }

    const {
      cycle,
      targetAmount,
      cumulativeAmount,
      remainingAmount,
    } = await getOpenCycleForFunding(userId, transaction);

    if (remainingAmount <= 0) {
      throw new AppError(
        "Ce cycle a deja atteint son objectif. Confirmez d'abord le reversement.",
        409,
      );
    }

    if (amount > remainingAmount) {
      throw new AppError(
        `Le montant depasse le reste a verser sur ce cycle. Reste autorise : ${remainingAmount} F.`,
        422,
      );
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    if (source === 'wallet' && Number(wallet.availableBalance) < amount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    const nextAmount = cumulativeAmount + amount;
    const nextStatus =
      nextAmount >= targetAmount ? 'enAttenteValidationFin' : 'active';

    if (source === 'wallet') {
      await wallet.update(
        {
          availableBalance: Number(wallet.availableBalance) - amount,
        },
        { transaction },
      );
    }

    await cycle.update(
      {
        cumulativeAmount: nextAmount,
        status: nextStatus,
      },
      { transaction },
    );
    await wallet.update({ tontineBalance: nextAmount }, { transaction });

    const availableHistory =
      source === 'wallet'
        ? await appendAvailableHistory(
            transaction,
            userId,
            'tontineFunding',
            amount,
            'Retour vers tontine',
            false,
          )
        : null;

    const cycleDepositLabel = getDepositHistoryLabel(source);
    const cycleHistory = await appendCycleHistory(
      transaction,
      userId,
      cycle.id,
      'deposit',
      amount,
      cycleDepositLabel,
      null,
      actor,
      {
        paymentSource: source,
        paymentIntentId: requestContext.paymentIntentId || null,
        paymentProvider: requestContext.paymentProvider || null,
        linkedProvisioningId: requestContext.provisioningId || null,
        availableBalanceHistoryId: availableHistory?.id || null,
      },
    );

    if (nextStatus === 'enAttenteValidationFin') {
      await appendCycleHistory(
        transaction,
        userId,
        cycle.id,
        'cycleCompleted',
        Number(cycle.stakeAmount) * 30,
        'Cycle atteint',
        'En attente de confirmation',
        actor,
      );
      await appendNotification(
        transaction,
        userId,
        'cycle',
        'Cycle atteint',
        "Votre tontine a atteint l'objectif. Confirmez le reversement.",
      );
    } else {
      const depositNotificationTitle = getDepositNotificationTitle(source);
      const depositNotificationMessage = getDepositNotificationMessage(
        source,
        amount,
      );
      await appendNotification(
        transaction,
        userId,
        'deposit',
        depositNotificationTitle,
        depositNotificationMessage,
      );
    }

    await writeAuditLog({
      userId,
      action: 'tontine.deposit',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        amount,
        source,
        paymentIntentId: requestContext.paymentIntentId || null,
        paymentProvider: requestContext.paymentProvider || null,
        nextAmount,
        nextStatus,
      },
      transaction,
    });

    const commissionSourceId = requestContext.provisioningId || cycleHistory.id;
    await postDepositCommissions({
      transaction,
      cycle,
      userId,
      amount,
      sourceType: 'tontine_deposit',
      sourceId: commissionSourceId,
      initiatedByUserId: actor.initiatedByUserId,
      initiatorType: actor.initiatorType,
      requestContext,
    });

    if (requestContext.provisioningId) {
      await models.TontineHistory.update(
        {
          linkedProvisioningId: requestContext.provisioningId,
        },
        {
          where: { id: cycleHistory.id },
          transaction,
        },
      );
    }

    return {
      ...serializeCycle(cycle),
      historyId: cycleHistory.id,
    };
  };

  if (requestContext.transaction) {
    return executeDeposit(requestContext.transaction);
  }

  return sequelize.transaction(executeDeposit);
}

function resolveDepositPaymentSource(originalHistory) {
  if (originalHistory.paymentSource) {
    return originalHistory.paymentSource;
  }

  if (
    originalHistory.availableBalanceHistoryId ||
    String(originalHistory.label || '').includes('depuis disponible')
  ) {
    return 'wallet';
  }

  return 'external';
}

async function reverseTontineDepositByAdmin(
  userId,
  historyId,
  payload = {},
  requestContext = {},
) {
  const reason = String(payload?.reason || '').trim();
  if (!reason) {
    throw new AppError('Le motif de correction est requis.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    const client = await models.User.findByPk(userId, {
      include: [
        {
          model: models.AgentProfile,
          as: 'agentProfile',
          required: false,
        },
      ],
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!client) {
      throw new AppError('Client introuvable.', 404);
    }
    if (client.agentProfile) {
      throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
    }

    const originalHistory = await models.TontineHistory.findOne({
      where: {
        id: historyId,
        userId,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!originalHistory) {
      throw new AppError('Operation tontine introuvable.', 404);
    }
    if (originalHistory.type !== 'deposit') {
      throw new AppError(
        "Seules les cotisations tontine peuvent etre annulees automatiquement.",
        409,
      );
    }
    if (originalHistory.reversalOfHistoryId) {
      throw new AppError('Cette operation est deja une annulation.', 409);
    }

    const reversalExists = await models.TontineHistory.findOne({
      where: {
        reversalOfHistoryId: originalHistory.id,
      },
      transaction,
    });

    if (reversalExists) {
      throw new AppError('Cette operation a deja ete annulee.', 409);
    }

    const cycle = await models.TontineCycle.findOne({
      where: {
        id: originalHistory.cycleId,
        userId,
      },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!cycle) {
      throw new AppError('Cycle de tontine introuvable.', 404);
    }
    if (!['active', 'enAttenteValidationFin'].includes(cycle.status)) {
      throw new AppError(
        "Cette operation ne peut plus etre annulee car le cycle n'est plus ouvert.",
        409,
      );
    }

    const amount = Number(originalHistory.amount);
    const currentAmount = Number(cycle.cumulativeAmount);
    if (currentAmount < amount) {
      throw new AppError(
        'Le montant a annuler depasse le cumul actuel du cycle.',
        409,
      );
    }

    const paymentSource = resolveDepositPaymentSource(originalHistory);
    const wallet = await models.Wallet.findOne({
      where: { userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!wallet) {
      throw new AppError('Portefeuille introuvable.', 404);
    }

    const targetAmount = Number(cycle.stakeAmount) * 31;
    const nextAmount = currentAmount - amount;
    const nextStatus =
      nextAmount > 0 && nextAmount >= targetAmount
        ? 'enAttenteValidationFin'
        : 'active';

    let linkedFundingHistory = null;
    if (paymentSource === 'wallet') {
      linkedFundingHistory = await findWalletFundingHistoryForDeposit(
        originalHistory,
        transaction,
      );

      if (!linkedFundingHistory) {
        throw new AppError(
          "Impossible de retrouver l'ecriture de solde liee a cette cotisation.",
          409,
        );
      }

      await wallet.update(
        {
          availableBalance: Number(wallet.availableBalance) + amount,
          tontineBalance: nextAmount,
        },
        { transaction },
      );

      await appendAvailableHistory(
        transaction,
        userId,
        'tontineFundingReversal',
        amount,
        'Annulation versement tontine',
        true,
        {
          reversalOfHistoryId: linkedFundingHistory.id,
        },
      );
    } else {
      await wallet.update({ tontineBalance: nextAmount }, { transaction });
    }

    await cycle.update(
      {
        cumulativeAmount: nextAmount,
        status: nextStatus,
      },
      { transaction },
    );

    const reversalHistory = await appendCycleHistory(
      transaction,
      userId,
      cycle.id,
      'depositReversal',
      amount,
      'Annulation cotisation',
      reason,
      {
        initiatedByUserId: requestContext.initiatedByUserId || null,
        initiatorType: requestContext.initiatorType || 'admin',
      },
      {
        paymentSource,
        linkedProvisioningId: originalHistory.linkedProvisioningId || null,
        availableBalanceHistoryId: linkedFundingHistory?.id || null,
        reversalOfHistoryId: originalHistory.id,
      },
    );

    const commissionReversal = await reverseDepositCommissions({
      transaction,
      originalHistory,
      reason,
      requestContext: {
        initiatedByUserId: requestContext.initiatedByUserId || null,
        initiatorType: requestContext.initiatorType || 'admin',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
      },
    });

    await appendNotification(
      transaction,
      userId,
      'deposit',
      'Cotisation annulee',
      `${amount} F ont ete annules par un administrateur.`,
    );

    await writeAuditLog({
      userId: requestContext.initiatedByUserId || null,
      action: 'admin.tontine_deposit_reversed',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        clientUserId: userId,
        cycleId: cycle.id,
        originalHistoryId: originalHistory.id,
        reversalHistoryId: reversalHistory.id,
        amount,
        reason,
        paymentSource,
        commissionSourceId: commissionReversal.sourceId,
        reversedCommissionEntriesCount:
          commissionReversal.reversedEntriesCount,
        reversedCommissionAmount: commissionReversal.totalReversedAmount,
      },
      transaction,
    });

    return {
      cycle: serializeCycle(cycle),
      reversal: {
        id: reversalHistory.id,
        amount,
        reason,
        occurredAt: reversalHistory.occurredAt,
      },
    };
  });
}

async function reverseProvisioningDepositOnCycle({
  transaction,
  userId,
  cycleId,
  amount,
  requestContext = {},
  note = null,
}) {
  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `Le montant de la contrepassation doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }

  const actor = resolveActorForUser(userId, requestContext);
  const cycle = await models.TontineCycle.findOne({
    where: { id: cycleId, userId },
    transaction,
  });

  if (!cycle) {
    throw new AppError('Cycle de tontine introuvable pour la contrepassation.', 404);
  }

  if (!['active', 'enAttenteValidationFin'].includes(cycle.status)) {
    throw new AppError(
      "Ce depot ne peut plus etre contrepasse car le cycle n'est plus ouvert.",
      409,
    );
  }

  const currentAmount = Number(cycle.cumulativeAmount);
  if (currentAmount < amount) {
    throw new AppError(
      'Le montant a contrepasser depasse le cumul actuel du cycle.',
      409,
    );
  }

  const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
  const targetAmount = Number(cycle.stakeAmount) * 31;
  const nextAmount = currentAmount - amount;
  const nextStatus =
    nextAmount > 0 && nextAmount >= targetAmount
      ? 'enAttenteValidationFin'
      : 'active';

  await cycle.update(
    {
      cumulativeAmount: nextAmount,
      status: nextStatus,
    },
    { transaction },
  );
  await wallet.update({ tontineBalance: nextAmount }, { transaction });

  await appendCycleHistory(
    transaction,
    userId,
    cycle.id,
    'deposit',
    amount,
    'Contrepassation depot tontine',
    note,
    actor,
  );

  await appendNotification(
    transaction,
    userId,
    'deposit',
    'Depot corrige',
    `${amount} F retires de votre tontine suite a une correction d'operation.`,
  );

  await writeAuditLog({
    userId: actor.initiatedByUserId,
    action: 'tontine.depositReversed',
    entityType: 'tontineCycle',
    entityId: cycle.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      amount,
      nextAmount,
      nextStatus,
      note,
    },
    transaction,
  });

  return serializeCycle(cycle);
}

async function hasActiveOrAwaitingCycle(userId) {
  try {
    await getOpenCycleForFunding(userId);
    return true;
  } catch (error) {
    if (error instanceof AppError && error.statusCode === 409) {
      return false;
    }
    throw error;
  }
}

async function confirmCyclePayout(userId, requestContext = {}) {
  return sequelize.transaction(async (transaction) => {
    const actor = resolveActorForUser(userId, requestContext);
    const cycle = await getLatestCycle(userId, transaction);
    if (!cycle || cycle.status !== 'enAttenteValidationFin') {
      throw new AppError('Aucun cycle en attente de reversement.', 409);
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    const netPayoutAmount = Number(cycle.stakeAmount) * 30;
    const commissionResult = await createWithdrawalReserve({
      transaction,
      cycle,
      userId,
      respected: true,
      sourceAmount: netPayoutAmount,
      initiatedByUserId: actor.initiatedByUserId,
      initiatorType: actor.initiatorType,
      requestContext,
    });

    await wallet.update(
      {
        availableBalance:
          Number(wallet.availableBalance) +
          netPayoutAmount +
          Number(commissionResult.bonusAmount || 0),
        tontineBalance: 0,
      },
      { transaction },
    );
    await appendAvailableHistory(
      transaction,
      userId,
      'tontinePayout',
      netPayoutAmount,
      'Fin de cycle tontine',
      true,
    );
    if (Number(commissionResult.bonusAmount || 0) > 0) {
      await appendAvailableHistory(
        transaction,
        userId,
        'tontineBonus',
        Number(commissionResult.bonusAmount),
        'Bonus fidelite tontine',
        true,
      );
    }
    await appendCycleHistory(
      transaction,
      userId,
      cycle.id,
      'payoutConfirmed',
      netPayoutAmount,
      'Reversement confirme',
      null,
      actor,
    );
    await models.TontineArchive.create(
      {
        userId,
        stakeAmount: cycle.stakeAmount,
        targetAmount: Number(cycle.stakeAmount) * 31,
        cumulativeAmount: cycle.cumulativeAmount,
        commissionAmount: cycle.stakeAmount,
        netPayoutAmount,
        status: 'completed',
        startedAt: cycle.startedAt,
        expectedEndAt: cycle.expectedEndAt,
        endedAt: new Date(),
      },
      { transaction },
    );
    await cycle.update(
      {
        status: 'terminee',
        cumulativeAmount: Number(cycle.cumulativeAmount),
        endedAt: new Date(),
      },
      { transaction },
    );
    await appendNotification(
      transaction,
      userId,
      'cycle',
      'Reversement confirme',
      `${netPayoutAmount} F ajoutes a votre solde disponible.`,
    );
    await writeAuditLog({
      userId,
      action: 'tontine.payoutConfirmed',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        netPayoutAmount,
        bonusAmount: Number(commissionResult.bonusAmount || 0),
        reserveAmount: Number(
          commissionResult.reserve?.initialReservedAmount || 0,
        ),
        floatingAmount: Number(commissionResult.floatingAmount || 0),
      },
      transaction,
    });
    return serializeCycle(cycle);
  });
}

async function stopCycleEarly(userId, requestContext = {}) {
  return sequelize.transaction(async (transaction) => {
    const actor = resolveActorForUser(userId, requestContext);
    const cycle = await getLatestCycle(userId, transaction);
    if (!cycle || Number(cycle.cumulativeAmount) <= 0) {
      throw new AppError('Aucun cycle eligible a un arret anticipe.', 409);
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    const netAmount = Math.max(
      Number(cycle.cumulativeAmount) - Number(cycle.stakeAmount),
      0,
    );
    const commissionResult = await createWithdrawalReserve({
      transaction,
      cycle,
      userId,
      respected: false,
      sourceAmount: netAmount,
      initiatedByUserId: actor.initiatedByUserId,
      initiatorType: actor.initiatorType,
      requestContext,
    });

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) + netAmount,
        tontineBalance: 0,
      },
      { transaction },
    );
    await appendAvailableHistory(
      transaction,
      userId,
      'tontineEarlyStop',
      netAmount,
      'Arret anticipe tontine',
      true,
    );
    await appendCycleHistory(
      transaction,
      userId,
      cycle.id,
      'earlyStop',
      netAmount,
      'Arret anticipe',
      null,
      actor,
    );
    await models.TontineArchive.create(
      {
        userId,
        stakeAmount: cycle.stakeAmount,
        targetAmount: Number(cycle.stakeAmount) * 31,
        cumulativeAmount: cycle.cumulativeAmount,
        commissionAmount: cycle.stakeAmount,
        netPayoutAmount: netAmount,
        status: 'stoppedEarly',
        startedAt: cycle.startedAt,
        expectedEndAt: cycle.expectedEndAt,
        endedAt: new Date(),
      },
      { transaction },
    );
    await cycle.update(
      {
        status: 'arretee',
        cumulativeAmount: Number(cycle.cumulativeAmount),
        endedAt: new Date(),
      },
      { transaction },
    );
    await appendNotification(
      transaction,
      userId,
      'cycle',
      'Tontine arretee',
      `${netAmount} F reverses au solde disponible apres penalite.`,
    );
    await writeAuditLog({
      userId,
      action: 'tontine.stoppedEarly',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        netAmount,
        penaltyAmount: Number(cycle.stakeAmount),
        reserveAmount: Number(
          commissionResult.reserve?.initialReservedAmount || 0,
        ),
        floatingAmount: Number(commissionResult.floatingAmount || 0),
        forfeitedBonusAmount: Number(commissionResult.bonusAmount || 0),
      },
      transaction,
    });
    return serializeCycle(cycle);
  });
}

module.exports = {
  serializeCycle,
  getCycleOverview,
  configureStake,
  depositToCycle,
  hasActiveOrAwaitingCycle,
  getOpenCycleForFunding,
  reverseTontineDepositByAdmin,
  reverseProvisioningDepositOnCycle,
  confirmCyclePayout,
  stopCycleEarly,
};
