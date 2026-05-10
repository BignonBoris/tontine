const { fn, col } = require('sequelize');
const { models } = require('../../database/models');

function toNumber(value) {
  return Number(value || 0);
}

function serializeCommissionWallet(wallet) {
  if (!wallet) {
    return null;
  }

  return {
    id: wallet.id,
    ownerType: wallet.ownerType,
    ownerId: wallet.ownerId,
    walletType: wallet.walletType,
    balance: toNumber(wallet.balance),
    payableBalance: toNumber(wallet.payableBalance),
    blockedBalance: toNumber(wallet.blockedBalance),
    currency: wallet.currency,
  };
}

function serializeCommissionEntry(entry) {
  return {
    id: entry.id,
    reference: entry.reference,
    entryType: entry.entryType,
    status: entry.status,
    sourceType: entry.sourceType,
    sourceId: entry.sourceId,
    cycleId: entry.cycleId,
    clientId: entry.clientId,
    agentId: entry.agentId,
    direction: entry.direction,
    amount: toNumber(entry.amount),
    payableAmount: toNumber(entry.payableAmount),
    blockedAmount: toNumber(entry.blockedAmount),
    commissionBucket: entry.commissionBucket,
    triggerEvent: entry.triggerEvent,
    initiatedByUserId: entry.initiatedByUserId,
    initiatorType: entry.initiatorType,
    metadata: entry.metadata || {},
    createdAt: entry.createdAt,
  };
}

async function getAgentCommissionOverview(agentProfileId, options = {}) {
  const limit = Math.min(Math.max(Number(options.limit) || 20, 1), 100);

  const wallet = await models.CommissionWallet.findOne({
    where: {
      ownerType: 'agent',
      ownerId: String(agentProfileId),
      walletType: 'agent_commission',
    },
  });

  const walletId = wallet?.id || null;
  const where = walletId ? { walletId } : { agentId: agentProfileId };

  const [entries, totals] = await Promise.all([
    models.CommissionLedgerEntry.findAll({
      where,
      order: [['createdAt', 'DESC']],
      limit,
    }),
    models.CommissionLedgerEntry.findAll({
      where,
      attributes: [
        'commissionBucket',
        [fn('COALESCE', fn('SUM', col('amount')), 0), 'totalAmount'],
      ],
      group: ['commissionBucket'],
      raw: true,
    }),
  ]);

  return {
    wallet: serializeCommissionWallet(wallet),
    totalsByBucket: totals.map((item) => ({
      bucket: item.commissionBucket,
      amount: toNumber(item.totalAmount),
    })),
    recentEntries: entries.map(serializeCommissionEntry),
  };
}

module.exports = {
  getAgentCommissionOverview,
};
