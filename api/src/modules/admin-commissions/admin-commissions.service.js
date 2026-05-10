const { fn, col } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { models } = require('../../database/models');

function toNumber(value) {
  return Number(value || 0);
}

function serializeWallet(wallet) {
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
    createdAt: wallet.createdAt,
    updatedAt: wallet.updatedAt,
  };
}

function serializeEntry(entry) {
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
    initiatorType: entry.initiatorType,
    initiatedByUserId: entry.initiatedByUserId,
    metadata: entry.metadata || {},
    createdAt: entry.createdAt,
  };
}

async function getOverview(options = {}) {
  const walletLimit = Math.min(Math.max(Number(options.walletLimit) || 20, 1), 100);
  const entryLimit = Math.min(Math.max(Number(options.entryLimit) || 30, 1), 100);

  const [platformWallet, floatingWallet, agentWallets, totalsByBucket, recentEntries] =
    await Promise.all([
      models.CommissionWallet.findOne({
        where: {
          ownerType: 'platform',
          ownerId: 'main',
          walletType: 'platform_commission',
        },
      }),
      models.CommissionWallet.findOne({
        where: {
          ownerType: 'platform',
          ownerId: 'floating',
          walletType: 'platform_floating',
        },
      }),
      models.CommissionWallet.findAll({
        where: {
          ownerType: 'agent',
          walletType: 'agent_commission',
        },
        order: [['balance', 'DESC']],
        limit: walletLimit,
      }),
      models.CommissionLedgerEntry.findAll({
        attributes: [
          'commissionBucket',
          [fn('COALESCE', fn('SUM', col('amount')), 0), 'totalAmount'],
        ],
        where: {
          status: 'posted',
        },
        group: ['commissionBucket'],
        raw: true,
      }),
      models.CommissionLedgerEntry.findAll({
        order: [['createdAt', 'DESC']],
        limit: entryLimit,
      }),
    ]);

  const agentIds = agentWallets.map((wallet) => wallet.ownerId);
  const profiles = agentIds.length
    ? await models.AgentProfile.findAll({
        where: {
          id: agentIds,
        },
        include: [{ model: models.User, as: 'user', required: false }],
      })
    : [];

  const profileMap = new Map(
    profiles.map((profile) => [
      profile.id,
      {
        id: profile.id,
        agentCode: profile.agentCode,
        fullName: profile.fullName,
        userId: profile.userId,
        phoneNumber: profile.user?.phoneNumber || null,
      },
    ]),
  );

  return {
    platformWallet: serializeWallet(platformWallet),
    floatingWallet: serializeWallet(floatingWallet),
    totalsByBucket: totalsByBucket.map((item) => ({
      bucket: item.commissionBucket,
      amount: toNumber(item.totalAmount),
    })),
    agentWallets: agentWallets.map((wallet) => ({
      ...serializeWallet(wallet),
      agent: profileMap.get(wallet.ownerId) || null,
    })),
    recentEntries: recentEntries.map(serializeEntry),
  };
}

async function getAgentDetail(agentId, options = {}) {
  const entryLimit = Math.min(Math.max(Number(options.entryLimit) || 50, 1), 200);

  const profile = await models.AgentProfile.findOne({
    where: { id: agentId },
    include: [{ model: models.User, as: 'user', required: false }],
  });

  if (!profile) {
    throw new AppError('Agent introuvable.', 404);
  }

  const wallet = await models.CommissionWallet.findOne({
    where: {
      ownerType: 'agent',
      ownerId: String(agentId),
      walletType: 'agent_commission',
    },
  });

  const [entries, totalsByBucket, provisioningStats, withdrawalStats] = await Promise.all([
    models.CommissionLedgerEntry.findAll({
      where: {
        agentId,
      },
      order: [['createdAt', 'DESC']],
      limit: entryLimit,
    }),
    models.CommissionLedgerEntry.findAll({
      attributes: [
        'commissionBucket',
        [fn('COALESCE', fn('SUM', col('amount')), 0), 'totalAmount'],
      ],
      where: {
        agentId,
        status: 'posted',
      },
      group: ['commissionBucket'],
      raw: true,
    }),
    models.Provisioning.findOne({
      where: {
        agentProfileId: agentId,
      },
      attributes: [
        [fn('COUNT', col('id')), 'count'],
        [fn('COALESCE', fn('SUM', col('amount')), 0), 'totalAmount'],
      ],
      raw: true,
    }),
    models.Withdrawal.findOne({
      where: {
        paidByAgentProfileId: agentId,
        status: 'paid',
      },
      attributes: [
        [fn('COUNT', col('id')), 'count'],
        [fn('COALESCE', fn('SUM', col('amount')), 0), 'totalAmount'],
      ],
      raw: true,
    }),
  ]);

  return {
    agent: {
      id: profile.id,
      userId: profile.userId,
      agentCode: profile.agentCode,
      fullName: profile.fullName,
      phoneNumber: profile.user?.phoneNumber || null,
      isActive: profile.isActive,
    },
    wallet: serializeWallet(wallet),
    totalsByBucket: totalsByBucket.map((item) => ({
      bucket: item.commissionBucket,
      amount: toNumber(item.totalAmount),
    })),
    activity: {
      provisioningsCount: Number(provisioningStats?.count || 0),
      provisioningsAmount: toNumber(provisioningStats?.totalAmount),
      paidWithdrawalsCount: Number(withdrawalStats?.count || 0),
      paidWithdrawalsAmount: toNumber(withdrawalStats?.totalAmount),
    },
    recentEntries: entries.map(serializeEntry),
  };
}

module.exports = {
  getOverview,
  getAgentDetail,
};
