const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

function ensureStakeMultiple(stakeAmount) {
  if (!stakeAmount || stakeAmount <= 0 || stakeAmount % 500 !== 0) {
    throw new AppError('La mise doit etre un multiple positif de 500.', 422);
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
) {
  await models.AvailableBalanceHistory.create(
    {
      userId,
      type,
      amount,
      label,
      isCredit,
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
) {
  await models.TontineHistory.create(
    {
      userId,
      cycleId,
      type,
      amount,
      label,
      note,
      initiatedByUserId: actor.initiatedByUserId || null,
      initiatorType: actor.initiatorType || null,
    },
    { transaction },
  );
}

function resolveActorForUser(userId, requestContext = {}) {
  return {
    initiatedByUserId: requestContext.initiatedByUserId || userId,
    initiatorType: requestContext.initiatorType || 'client',
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
  if (!amount || amount <= 0 || amount % 500 !== 0) {
    throw new AppError('Le versement doit etre un multiple positif de 500.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    const actor = resolveActorForUser(userId, requestContext);
    if (source === 'external' && actor.initiatorType === 'client') {
      throw new AppError(
        "Les versements externes ne sont plus autorises depuis l'application client. Utilisez votre solde disponible.",
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
      await appendAvailableHistory(
        transaction,
        userId,
        'tontineFunding',
        amount,
        'Retour vers tontine',
        false,
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
    await appendCycleHistory(
      transaction,
      userId,
      cycle.id,
      'deposit',
      amount,
      source === 'wallet' ? 'Versement depuis disponible' : 'Versement tontine',
      null,
      actor,
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
      await appendNotification(
        transaction,
        userId,
        'deposit',
        source === 'wallet' ? 'Retour vers la tontine' : 'Versement tontine',
        `${amount} F ajoutes a votre tontine.`,
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
        nextAmount,
        nextStatus,
      },
      transaction,
    });

    return serializeCycle(cycle);
  });
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

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) + netPayoutAmount,
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
        cumulativeAmount: 0,
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
        cumulativeAmount: 0,
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
  confirmCyclePayout,
  stopCycleEarly,
};
