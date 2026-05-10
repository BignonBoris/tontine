const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');
const {
  truncateTo2,
  computeTargetAmount,
  computeCycleCap,
  computeProgressAmount,
  computeFloatingAmount,
  computeReserveConsumption,
  planReserveConsumptions,
} = require('./commission-calculator');

function generateReference(prefix) {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 9000)
    .toString()
    .padStart(4, '0')}`;
}

async function getActiveCommissionRule(transaction) {
  const rule = await models.CommissionRule.findOne({
    where: {
      status: 'active',
      [Op.or]: [{ effectiveTo: null }, { effectiveTo: { [Op.gt]: new Date() } }],
    },
    order: [['effectiveFrom', 'DESC']],
    transaction,
  });

  if (!rule) {
    throw new AppError(
      'Aucune regle de commission active n est configuree.',
      409,
    );
  }

  return rule;
}

async function createCycleCommissionSnapshot({
  transaction,
  cycle,
  userId,
}) {
  const existing = await models.CycleCommissionSnapshot.findOne({
    where: { tontineCycleId: cycle.id },
    transaction,
  });
  if (existing) {
    return existing;
  }

  const rule = await getActiveCommissionRule(transaction);
  const stakeAmount = Number(cycle.stakeAmount);
  const cycleCommissionAmount = truncateTo2(
    Number(rule.fixedCycleCommissionAmount) > 0
      ? Number(rule.fixedCycleCommissionAmount)
      : stakeAmount,
  );

  return models.CycleCommissionSnapshot.create(
    {
      tontineCycleId: cycle.id,
      commissionRuleId: rule.id,
      userId,
      stakeAmount,
      cycleCommissionAmount,
      platformShareRate: Number(rule.platformShareRate),
      depositAgentShareRate: Number(rule.depositAgentShareRate),
      withdrawalAgentShareRate: Number(rule.withdrawalAgentShareRate),
      bonusShareRate: Number(rule.bonusShareRate),
      floatingEnabled: Boolean(rule.floatingEnabled),
      snapshotPayload: {
        ruleId: rule.id,
        ruleCode: rule.code,
        ruleName: rule.name,
        calculationMode: rule.calculationMode,
        fixedCycleCommissionAmount: Number(rule.fixedCycleCommissionAmount),
        platformShareRate: Number(rule.platformShareRate),
        depositAgentShareRate: Number(rule.depositAgentShareRate),
        withdrawalAgentShareRate: Number(rule.withdrawalAgentShareRate),
        bonusShareRate: Number(rule.bonusShareRate),
        floatingEnabled: Boolean(rule.floatingEnabled),
        frozenAt: new Date().toISOString(),
      },
    },
    { transaction },
  );
}

async function getOrCreateCommissionWallet({
  transaction,
  ownerType,
  ownerId,
  walletType,
}) {
  const [wallet] = await models.CommissionWallet.findOrCreate({
    where: {
      ownerType,
      ownerId: String(ownerId),
      walletType,
    },
    defaults: {
      ownerType,
      ownerId: String(ownerId),
      walletType,
      balance: 0,
      payableBalance: 0,
      blockedBalance: 0,
      currency: 'XOF',
    },
    transaction,
  });

  return wallet;
}

async function postCommissionCredit({
  transaction,
  wallet,
  amount,
  entryType,
  commissionBucket,
  sourceType,
  sourceId,
  cycleId,
  clientId = null,
  agentId = null,
  snapshotId = null,
  triggerEvent = null,
  initiatorType = null,
  initiatedByUserId = null,
  metadata = {},
}) {
  const normalizedAmount = truncateTo2(amount);
  if (normalizedAmount <= 0) {
    return null;
  }

  await wallet.update(
    {
      balance: truncateTo2(Number(wallet.balance) + normalizedAmount),
      payableBalance: truncateTo2(Number(wallet.payableBalance) + normalizedAmount),
    },
    { transaction },
  );

  return models.CommissionLedgerEntry.create(
    {
      reference: generateReference('COM'),
      entryType,
      status: 'posted',
      sourceType,
      sourceId: sourceId ? String(sourceId) : null,
      cycleId,
      clientId,
      agentId,
      walletId: wallet.id,
      direction: 'credit',
      amount: normalizedAmount,
      payableAmount: normalizedAmount,
      blockedAmount: 0,
      commissionBucket,
      snapshotId,
      triggerEvent,
      initiatorType,
      initiatedByUserId,
      metadata,
    },
    { transaction },
  );
}

async function ensureSnapshotForCycle({ transaction, cycle, userId }) {
  const existing = await models.CycleCommissionSnapshot.findOne({
    where: { tontineCycleId: cycle.id },
    transaction,
  });
  if (existing) {
    return existing;
  }
  return createCycleCommissionSnapshot({ transaction, cycle, userId });
}

async function postDepositCommissions({
  transaction,
  cycle,
  userId,
  amount,
  sourceType,
  sourceId,
  initiatedByUserId,
  initiatorType,
  requestContext = {},
}) {
  if (initiatorType !== 'agent' || !initiatedByUserId) {
    return null;
  }

  const snapshot = await ensureSnapshotForCycle({ transaction, cycle, userId });
  const targetAmount = computeTargetAmount(cycle.stakeAmount);
  const depositAgentCap = computeCycleCap(
    snapshot.cycleCommissionAmount,
    snapshot.depositAgentShareRate,
  );
  const platformCap = computeCycleCap(
    snapshot.cycleCommissionAmount,
    snapshot.platformShareRate,
  );

  const agentCommissionAmount = computeProgressAmount(amount, targetAmount, depositAgentCap);
  const platformCommissionAmount = computeProgressAmount(amount, targetAmount, platformCap);

  const agentProfile = await models.AgentProfile.findOne({
    where: { userId: initiatedByUserId },
    transaction,
  });
  if (!agentProfile) {
    throw new AppError('Profil agent introuvable pour la commission de depot.', 404);
  }

  const agentWallet = await getOrCreateCommissionWallet({
    transaction,
    ownerType: 'agent',
    ownerId: agentProfile.id,
    walletType: 'agent_commission',
  });
  const platformWallet = await getOrCreateCommissionWallet({
    transaction,
    ownerType: 'platform',
    ownerId: 'main',
    walletType: 'platform_commission',
  });

  const agentEntry = await postCommissionCredit({
    transaction,
    wallet: agentWallet,
    amount: agentCommissionAmount,
    entryType: 'deposit_agent_commission_credit',
    commissionBucket: 'deposit_agent',
    sourceType,
    sourceId,
    cycleId: cycle.id,
    clientId: userId,
    agentId: agentProfile.id,
    snapshotId: snapshot.id,
    triggerEvent: 'deposit',
    initiatorType,
    initiatedByUserId,
    metadata: {
      depositAmount: amount,
      targetAmount,
      cycleCommissionAmount: Number(snapshot.cycleCommissionAmount),
    },
  });

  const platformEntry = await postCommissionCredit({
    transaction,
    wallet: platformWallet,
    amount: platformCommissionAmount,
    entryType: 'deposit_platform_commission_credit',
    commissionBucket: 'platform',
    sourceType,
    sourceId,
    cycleId: cycle.id,
    clientId: userId,
    snapshotId: snapshot.id,
    triggerEvent: 'deposit',
    initiatorType,
    initiatedByUserId,
    metadata: {
      depositAmount: amount,
      targetAmount,
      cycleCommissionAmount: Number(snapshot.cycleCommissionAmount),
      origin: 'deposit',
    },
  });

  await writeAuditLog({
    userId: initiatedByUserId,
    action: 'commission.deposit.posted',
    entityType: 'tontineCycle',
    entityId: cycle.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      sourceType,
      sourceId,
      amount,
      agentCommissionAmount,
      platformCommissionAmount,
      agentEntryId: agentEntry?.id || null,
      platformEntryId: platformEntry?.id || null,
    },
    transaction,
  });

  return { agentEntry, platformEntry, snapshot };
}

async function createWithdrawalReserve({
  transaction,
  cycle,
  userId,
  respected,
  sourceAmount,
  initiatedByUserId,
  initiatorType,
  requestContext = {},
}) {
  const snapshot = await ensureSnapshotForCycle({ transaction, cycle, userId });
  const targetAmount = computeTargetAmount(cycle.stakeAmount);
  const cumulativeAmount = Number(cycle.cumulativeAmount);
  const withdrawalCap = computeCycleCap(
    snapshot.cycleCommissionAmount,
    snapshot.withdrawalAgentShareRate,
  );
  const bonusAmount = computeCycleCap(
    snapshot.cycleCommissionAmount,
    snapshot.bonusShareRate,
  );
  const platformCap = computeCycleCap(
    snapshot.cycleCommissionAmount,
    snapshot.platformShareRate,
  );
  const depositCap = computeCycleCap(
    snapshot.cycleCommissionAmount,
    snapshot.depositAgentShareRate,
  );

  const reserveAmount = computeProgressAmount(
    cumulativeAmount,
    targetAmount,
    withdrawalCap,
  );
  const platformConsumed = computeProgressAmount(
    cumulativeAmount,
    targetAmount,
    platformCap,
  );
  const depositConsumed = computeProgressAmount(
    cumulativeAmount,
    targetAmount,
    depositCap,
  );
  const floatingAmount = computeFloatingAmount({
    cycleCommissionAmount: snapshot.cycleCommissionAmount,
    depositConsumed,
    platformConsumed,
    reserveAmount,
    bonusAmount,
  });

  const sequence =
    ((await models.WithdrawalCommissionReserve.max('sequence', {
      where: { clientId: userId },
      transaction,
    })) || 0) + 1;

  const reserve = await models.WithdrawalCommissionReserve.create(
    {
      clientId: userId,
      cycleId: cycle.id,
      snapshotId: snapshot.id,
      stakeAmount: cycle.stakeAmount,
      sourceAmount,
      remainingSourceAmount: sourceAmount,
      consumedSourceAmount: 0,
      initialReservedAmount: reserveAmount,
      availableAmount: reserveAmount,
      consumedAmount: 0,
      sequence,
      status: reserveAmount > 0 ? 'open' : 'closed',
    },
    { transaction },
  );

  let bonusPlatformEntry = null;
  let floatingEntry = null;

  if (!respected && bonusAmount > 0) {
    const platformWallet = await getOrCreateCommissionWallet({
      transaction,
      ownerType: 'platform',
      ownerId: 'main',
      walletType: 'platform_commission',
    });
    bonusPlatformEntry = await postCommissionCredit({
      transaction,
      wallet: platformWallet,
      amount: bonusAmount,
      entryType: 'cycle_bonus_platform_credit',
      commissionBucket: 'bonus',
      sourceType: 'tontine_cycle',
      sourceId: cycle.id,
      cycleId: cycle.id,
      clientId: userId,
      snapshotId: snapshot.id,
      triggerEvent: 'cycle_stop',
      initiatorType,
      initiatedByUserId,
      metadata: {
        respected,
        origin: 'bonus_forfeited',
      },
    });
  }

  if (floatingAmount > 0 && snapshot.floatingEnabled) {
    const floatingWallet = await getOrCreateCommissionWallet({
      transaction,
      ownerType: 'platform',
      ownerId: 'floating',
      walletType: 'platform_floating',
    });
    floatingEntry = await postCommissionCredit({
      transaction,
      wallet: floatingWallet,
      amount: floatingAmount,
      entryType: 'floating_credit',
      commissionBucket: 'floating',
      sourceType: 'tontine_cycle',
      sourceId: cycle.id,
      cycleId: cycle.id,
      clientId: userId,
      snapshotId: snapshot.id,
      triggerEvent: respected ? 'cycle_close' : 'cycle_stop',
      initiatorType,
      initiatedByUserId,
      metadata: {
        respected,
        reserveAmount,
        bonusAmount,
        platformConsumed,
        depositConsumed,
      },
    });
  }

  await writeAuditLog({
    userId: initiatedByUserId || userId,
    action: 'commission.reserve.created',
    entityType: 'tontineCycle',
    entityId: cycle.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      respected,
      reserveAmount,
      sourceAmount,
      bonusAmount,
      floatingAmount,
      reserveId: reserve.id,
      bonusPlatformEntryId: bonusPlatformEntry?.id || null,
      floatingEntryId: floatingEntry?.id || null,
    },
    transaction,
  });

  return {
    snapshot,
    reserve,
    bonusAmount,
    floatingAmount,
    bonusPlatformEntry,
    floatingEntry,
  };
}

async function consumeWithdrawalCommissionReserves({
  transaction,
  clientId,
  withdrawalId,
  withdrawalAmount,
  agentProfileId = null,
  initiatedByUserId = null,
  initiatorType = null,
}) {
  let remainingPrincipal = truncateTo2(withdrawalAmount);
  const reserves = await models.WithdrawalCommissionReserve.findAll({
    where: {
      clientId,
      status: 'open',
    },
    include: [{ model: models.CycleCommissionSnapshot, as: 'snapshot' }],
    order: [['sequence', 'ASC']],
    transaction,
  });

  const plan = planReserveConsumptions({
    reserves: reserves.map((reserve) => ({
      id: reserve.id,
      cycleId: reserve.cycleId,
      sourceAmount: Number(reserve.sourceAmount),
      remainingSourceAmount: Number(reserve.remainingSourceAmount),
      consumedSourceAmount: Number(reserve.consumedSourceAmount),
      initialReservedAmount: Number(reserve.initialReservedAmount),
      availableAmount: Number(reserve.availableAmount),
      consumedAmount: Number(reserve.consumedAmount),
      status: reserve.status,
      withdrawalAgentShareRate: Number(
        reserve.snapshot?.withdrawalAgentShareRate || 0,
      ),
      platformShareRate: Number(reserve.snapshot?.platformShareRate || 0),
    })),
    withdrawalAmount: remainingPrincipal,
  });

  const consumptions = [];
  for (const reserve of reserves) {
    const updatedReserve = plan.updatedReserves.find((item) => item.id === reserve.id);
    if (!updatedReserve) {
      continue;
    }
    await reserve.update(
      {
        remainingSourceAmount: updatedReserve.remainingSourceAmount,
        consumedSourceAmount: updatedReserve.consumedSourceAmount,
        availableAmount: updatedReserve.availableAmount,
        consumedAmount: updatedReserve.consumedAmount,
        status: updatedReserve.status,
      },
      { transaction },
    );

    const breakdown = plan.consumptions.find((item) => item.reserveId === reserve.id);
    if (!breakdown) {
      continue;
    }

    const consumption = await models.WithdrawalCommissionConsumption.create(
      {
        reference: generateReference('WCC'),
        withdrawalId: String(withdrawalId),
        clientId,
        reserveId: reserve.id,
        cycleId: reserve.cycleId,
        agentId: agentProfileId,
        consumedAmount: breakdown.principalConsumed,
        agentCommissionAmount: breakdown.agentCommissionAmount,
        platformCommissionAmount: breakdown.platformCommissionAmount,
      },
      { transaction },
    );

    consumptions.push({
      reserveId: reserve.id,
      cycleId: reserve.cycleId,
      principalConsumed: breakdown.principalConsumed,
      commissionConsumed: breakdown.commissionConsumed,
      agentCommissionAmount: breakdown.agentCommissionAmount,
      platformCommissionAmount: breakdown.platformCommissionAmount,
      consumptionId: consumption.id,
    });
  }

  return {
    fullyCovered: plan.fullyCovered,
    remainingPrincipal: plan.remainingPrincipal,
    consumptions,
  };
}

async function postWithdrawalCommissions({
  transaction,
  clientId,
  cycleId = null,
  withdrawalId,
  sourceType,
  sourceId,
  agentProfileId,
  consumptions,
  initiatedByUserId,
  initiatorType,
  requestContext = {},
}) {
  const totals = consumptions.reduce(
    (accumulator, item) => {
      accumulator.agent += Number(item.agentCommissionAmount || 0);
      accumulator.platform += Number(item.platformCommissionAmount || 0);
      return accumulator;
    },
    { agent: 0, platform: 0 },
  );

  const agentWallet = await getOrCreateCommissionWallet({
    transaction,
    ownerType: 'agent',
    ownerId: agentProfileId,
    walletType: 'agent_commission',
  });
  const platformWallet = await getOrCreateCommissionWallet({
    transaction,
    ownerType: 'platform',
    ownerId: 'main',
    walletType: 'platform_commission',
  });

  const agentEntry = await postCommissionCredit({
    transaction,
    wallet: agentWallet,
    amount: totals.agent,
    entryType: 'withdrawal_agent_commission_credit',
    commissionBucket: 'withdrawal_agent',
    sourceType,
    sourceId,
    cycleId,
    clientId,
    agentId: agentProfileId,
    triggerEvent: 'withdrawal_paid',
    initiatorType,
    initiatedByUserId,
    metadata: {
      withdrawalId,
      consumptions,
    },
  });

  const platformEntry = await postCommissionCredit({
    transaction,
    wallet: platformWallet,
    amount: totals.platform,
    entryType: 'withdrawal_platform_commission_credit',
    commissionBucket: 'platform',
    sourceType,
    sourceId,
    cycleId,
    clientId,
    triggerEvent: 'withdrawal_paid',
    initiatorType,
    initiatedByUserId,
    metadata: {
      withdrawalId,
      consumptions,
      origin: 'withdrawal',
    },
  });

  await writeAuditLog({
    userId: initiatedByUserId,
    action: 'commission.withdrawal.posted',
    entityType: 'withdrawal',
    entityId: withdrawalId,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      sourceType,
      sourceId,
      clientId,
      agentProfileId,
      agentCommissionAmount: totals.agent,
      platformCommissionAmount: totals.platform,
      agentEntryId: agentEntry?.id || null,
      platformEntryId: platformEntry?.id || null,
      consumptions,
    },
    transaction,
  });

  return {
    agentCommissionAmount: truncateTo2(totals.agent),
    platformCommissionAmount: truncateTo2(totals.platform),
    agentEntry,
    platformEntry,
  };
}

async function reverseCommissionCredits({
  transaction,
  sourceType,
  sourceId,
  initiatedByUserId = null,
  initiatorType = null,
  reason = null,
  requestContext = {},
}) {
  const normalizedSourceId = sourceId ? String(sourceId) : null;
  if (!sourceType || !normalizedSourceId) {
    throw new AppError('La source de contrepassation des commissions est requise.', 422);
  }

  const entries = await models.CommissionLedgerEntry.findAll({
    where: {
      sourceType,
      sourceId: normalizedSourceId,
      direction: 'credit',
      status: 'posted',
    },
    include: [{ model: models.CommissionWallet, as: 'wallet', required: false }],
    order: [['createdAt', 'ASC']],
    transaction,
  });

  if (!entries.length) {
    return {
      reversedEntriesCount: 0,
      totalReversedAmount: 0,
      reversalEntries: [],
    };
  }

  const reversalEntries = [];
  let totalReversedAmount = 0;

  for (const entry of entries) {
    const wallet = entry.wallet;
    if (!wallet) {
      throw new AppError('Wallet commission introuvable pour la contrepassation.', 404);
    }

    const amount = truncateTo2(Number(entry.amount));
    const payableAmount = truncateTo2(Number(entry.payableAmount));
    const blockedAmount = truncateTo2(Number(entry.blockedAmount));

    if (
      Number(wallet.balance) < amount ||
      Number(wallet.payableBalance) < payableAmount ||
      Number(wallet.blockedBalance) < blockedAmount
    ) {
      throw new AppError(
        'Impossible de contrepasser une commission deja consommee ou indisponible.',
        409,
      );
    }

    await wallet.update(
      {
        balance: truncateTo2(Number(wallet.balance) - amount),
        payableBalance: truncateTo2(Number(wallet.payableBalance) - payableAmount),
        blockedBalance: truncateTo2(Number(wallet.blockedBalance) - blockedAmount),
      },
      { transaction },
    );

    const reversalEntry = await models.CommissionLedgerEntry.create(
      {
        reference: generateReference('COMR'),
        entryType: `${entry.entryType}_reversal`,
        status: 'posted',
        sourceType,
        sourceId: normalizedSourceId,
        cycleId: entry.cycleId,
        clientId: entry.clientId,
        agentId: entry.agentId,
        walletId: wallet.id,
        direction: 'debit',
        amount,
        payableAmount,
        blockedAmount,
        currency: entry.currency,
        commissionBucket: entry.commissionBucket,
        snapshotId: entry.snapshotId,
        triggerEvent: 'reversal',
        initiatorType,
        initiatedByUserId,
        reversalOfEntryId: entry.id,
        metadata: {
          ...entry.metadata,
          reversalReason: reason,
          reversedEntryReference: entry.reference,
          reversedAt: new Date().toISOString(),
        },
      },
      { transaction },
    );

    await entry.update(
      {
        status: 'reversed',
        metadata: {
          ...(entry.metadata || {}),
          reversedByEntryId: reversalEntry.id,
          reversalReason: reason,
          reversedAt: new Date().toISOString(),
        },
      },
      { transaction },
    );

    totalReversedAmount = truncateTo2(totalReversedAmount + amount);
    reversalEntries.push(reversalEntry);
  }

  await writeAuditLog({
    userId: initiatedByUserId,
    action: 'commission.reversed',
    entityType: sourceType,
    entityId: normalizedSourceId,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      reason,
      reversedEntriesCount: reversalEntries.length,
      totalReversedAmount,
      reversalEntryIds: reversalEntries.map((entry) => entry.id),
    },
    transaction,
  });

  return {
    reversedEntriesCount: reversalEntries.length,
    totalReversedAmount,
    reversalEntries,
  };
}

module.exports = {
  truncateTo2,
  generateReference,
  getActiveCommissionRule,
  createCycleCommissionSnapshot,
  getOrCreateCommissionWallet,
  postDepositCommissions,
  createWithdrawalReserve,
  consumeWithdrawalCommissionReserves,
  postWithdrawalCommissions,
  reverseCommissionCredits,
};
