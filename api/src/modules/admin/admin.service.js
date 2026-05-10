const { Op, fn, col, where } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { models, sequelize } = require('../../database/models');
const {
  applyAgentBalanceChange,
  generateCashReference,
} = require('../agent-cash/agent-cash.service');
const {
  reverseProvisioningByAdmin,
} = require('../agent-provisionings/agent-provisionings.service');

function parsePagination(query = {}) {
  const page = Math.max(Number(query.page || 1), 1);
  const pageSize = Math.min(Math.max(Number(query.pageSize || 10), 1), 100);

  return {
    page,
    pageSize,
    offset: (page - 1) * pageSize,
    limit: pageSize,
  };
}

function toNumber(value) {
  if (value == null) {
    return 0;
  }
  return Number(value) || 0;
}

function buildPastDays(days) {
  const values = [];
  const now = new Date();

  for (let index = days - 1; index >= 0; index -= 1) {
    const current = new Date(now);
    current.setHours(0, 0, 0, 0);
    current.setDate(now.getDate() - index);
    values.push(current);
  }

  return values;
}

function formatDayKey(value) {
  return value.toISOString().slice(0, 10);
}

function formatDayLabel(value) {
  return value.toLocaleDateString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
  });
}

function mergeSeries(days, rows, valueKey) {
  const map = new Map(
    rows.map((row) => [String(row.day), toNumber(row[valueKey])]),
  );

  return days.map((day) => {
    const key = formatDayKey(day);

    return {
      label: formatDayLabel(day),
      value: map.get(key) || 0,
    };
  });
}

function serializeWithdrawalEntry(entry) {
  return {
    id: entry.id,
    reference: entry.reference,
    amount: toNumber(entry.amount),
    status: entry.status,
    channel: entry.channel,
    requestedAt: entry.requestedAt,
    paidAt: entry.paidAt,
    cancelledAt: entry.cancelledAt,
    initiatorType: entry.initiatorType,
    cancellationReason: entry.cancellationReason,
    client: entry.user
      ? {
          id: entry.user.id,
          displayName: entry.user.displayName,
          phoneNumber: entry.user.phoneNumber,
        }
      : null,
  };
}

async function sumRequestedWithdrawalsByUser() {
  const rows = await models.Withdrawal.findAll({
    attributes: [
      'userId',
      [fn('SUM', col('amount')), 'reservedAmount'],
    ],
    where: { status: 'requested' },
    group: ['user_id'],
    raw: true,
  });

  return new Map(
    rows.map((row) => [row.userId, toNumber(row.reservedAmount)]),
  );
}

async function getOverview() {
  const seriesDays = buildPastDays(7);
  const firstDay = seriesDays[0];
  const [
    totalClients,
    activeClients,
    totalAgents,
    activeAgents,
    pendingWithdrawals,
    totalRequestedWithdrawals,
    totalPaidWithdrawals,
    totalAvailableBalances,
    totalAgentBalances,
    recentAuditLogs,
    totalReservedWithdrawals,
    newClientsSeriesRows,
    withdrawalVolumeSeriesRows,
    withdrawalStatusRows,
  ] = await Promise.all([
    models.User.count({
      include: [
        {
          model: models.AgentProfile,
          as: 'agentProfile',
          required: false,
        },
      ],
      where: {
        '$agentProfile.id$': null,
      },
    }),
    models.User.count({
      include: [
        {
          model: models.AgentProfile,
          as: 'agentProfile',
          required: false,
        },
      ],
      where: {
        isActive: true,
        '$agentProfile.id$': null,
      },
    }),
    models.AgentProfile.count(),
    models.AgentProfile.count({ where: { isActive: true } }),
    models.Withdrawal.count({ where: { status: 'requested' } }),
    models.Withdrawal.sum('amount', { where: { status: 'requested' } }),
    models.Withdrawal.sum('amount', { where: { status: 'paid' } }),
    models.Wallet.sum('availableBalance'),
    models.AgentProfile.sum('agentBalance'),
    models.AuditLog.findAll({
      limit: 8,
      order: [['createdAt', 'DESC']],
      include: [{ model: models.User, as: 'user', required: false }],
    }),
    models.Wallet.sum('reservedWithdrawalBalance'),
    models.User.findAll({
      attributes: [
        [fn('DATE', col('created_at')), 'day'],
        [fn('COUNT', col('id')), 'count'],
      ],
      include: [
        {
          model: models.AgentProfile,
          as: 'agentProfile',
          required: false,
          attributes: [],
        },
      ],
      where: {
        '$agentProfile.id$': null,
        createdAt: {
          [Op.gte]: firstDay,
        },
      },
      group: [fn('DATE', col('created_at'))],
      raw: true,
    }),
    models.Withdrawal.findAll({
      attributes: [
        [fn('DATE', col('created_at')), 'day'],
        [fn('SUM', col('amount')), 'totalAmount'],
      ],
      where: {
        createdAt: {
          [Op.gte]: firstDay,
        },
      },
      group: [fn('DATE', col('created_at'))],
      raw: true,
    }),
    models.Withdrawal.findAll({
      attributes: ['status', [fn('COUNT', col('id')), 'count']],
      group: ['status'],
      raw: true,
    }),
  ]);

  return {
    totals: {
      totalClients,
      activeClients,
      totalAgents,
      activeAgents,
      pendingWithdrawals,
      totalRequestedWithdrawals: toNumber(totalRequestedWithdrawals),
      totalPaidWithdrawals: toNumber(totalPaidWithdrawals),
      totalAvailableBalances: toNumber(totalAvailableBalances),
      totalAgentBalances: toNumber(totalAgentBalances),
      totalReservedWithdrawals: toNumber(totalReservedWithdrawals),
    },
    charts: {
      newClients: mergeSeries(seriesDays, newClientsSeriesRows, 'count'),
      withdrawalVolumes: mergeSeries(
        seriesDays,
        withdrawalVolumeSeriesRows,
        'totalAmount',
      ),
      withdrawalStatusBreakdown: withdrawalStatusRows.map((row) => ({
        label: row.status,
        value: toNumber(row.count),
      })),
    },
    recentAuditLogs: recentAuditLogs.map((entry) => ({
      id: entry.id,
      action: entry.action,
      entityType: entry.entityType,
      entityId: entry.entityId,
      status: entry.status,
      createdAt: entry.createdAt,
      user: entry.user
        ? {
            id: entry.user.id,
            displayName: entry.user.displayName,
            phoneNumber: entry.user.phoneNumber,
          }
        : null,
    })),
  };
}

async function listClients(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const search = String(query.search || '').trim();
  const status = String(query.status || '').trim().toLowerCase();

  const whereClause = {
    '$agentProfile.id$': null,
  };
  if (status === 'active') {
    whereClause.isActive = true;
  } else if (status === 'inactive') {
    whereClause.isActive = false;
  }

  if (search) {
    whereClause[Op.or] = [
      where(fn('LOWER', col('User.display_name')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('User.phone_number')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
    ];
  }

  const result = await models.User.findAndCountAll({
    where: whereClause,
    include: [
      {
        model: models.AgentProfile,
        as: 'agentProfile',
        required: false,
      },
      {
        model: models.Wallet,
        as: 'wallet',
        required: false,
      },
      {
        model: models.AgentProfile,
        as: 'creatorAgent',
        required: false,
      },
    ],
    order: [['createdAt', 'DESC']],
    offset,
    limit,
  });

  const items = result.rows
    .map((entry) => ({
      id: entry.id,
      displayName: entry.displayName,
      phoneNumber: entry.phoneNumber,
      accountType: entry.accountType,
      address: entry.address,
      isActive: entry.isActive,
      memberSince: entry.memberSince,
      createdAt: entry.createdAt,
      availableBalance: toNumber(entry.wallet?.availableBalance),
      reservedWithdrawalBalance: toNumber(
        entry.wallet?.reservedWithdrawalBalance,
      ),
      tontineBalance: toNumber(entry.wallet?.tontineBalance),
      createdByAgent: entry.creatorAgent
        ? {
            id: entry.creatorAgent.id,
            agentCode: entry.creatorAgent.agentCode,
            fullName: entry.creatorAgent.fullName,
          }
        : null,
    }));

  return {
    items,
    pagination: {
      page,
      pageSize,
      total: result.count,
    },
  };
}

async function getClientDetail(userId) {
  const client = await models.User.findByPk(userId, {
    include: [
      { model: models.AgentProfile, as: 'agentProfile', required: false },
      { model: models.Wallet, as: 'wallet', required: false },
      { model: models.AgentProfile, as: 'creatorAgent', required: false },
    ],
  });

  if (!client) {
    throw new AppError('Client introuvable.', 404);
  }
  if (client.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }

  const [cycles, goals, withdrawals, balanceHistory, tontineHistory] =
    await Promise.all([
      models.TontineCycle.findAll({
        where: { userId },
        order: [['createdAt', 'DESC']],
        limit: 5,
      }),
      models.Goal.findAll({
        where: { userId },
        order: [['createdAt', 'DESC']],
        limit: 5,
      }),
      models.Withdrawal.findAll({
        where: { userId },
        order: [['createdAt', 'DESC']],
        limit: 10,
      }),
      models.AvailableBalanceHistory.findAll({
        where: { userId },
        order: [['occurredAt', 'DESC']],
        limit: 10,
      }),
      models.TontineHistory.findAll({
        where: { userId },
        order: [['occurredAt', 'DESC']],
        limit: 10,
      }),
    ]);

  return {
    client: {
      id: client.id,
      displayName: client.displayName,
      phoneNumber: client.phoneNumber,
      accountType: client.accountType,
      address: client.address,
      isActive: client.isActive,
      memberSince: client.memberSince,
      createdAt: client.createdAt,
      wallet: {
        availableBalance: toNumber(client.wallet?.availableBalance),
        reservedWithdrawalBalance: toNumber(
          client.wallet?.reservedWithdrawalBalance,
        ),
        tontineBalance: toNumber(client.wallet?.tontineBalance),
      },
      createdByAgent: client.creatorAgent
        ? {
            id: client.creatorAgent.id,
            agentCode: client.creatorAgent.agentCode,
            fullName: client.creatorAgent.fullName,
          }
        : null,
    },
    cycles: cycles.map((entry) => ({
      id: entry.id,
      stakeAmount: toNumber(entry.stakeAmount),
      cumulativeAmount: toNumber(entry.cumulativeAmount),
      status: entry.status,
      startedAt: entry.startedAt,
      expectedEndAt: entry.expectedEndAt,
      endedAt: entry.endedAt,
    })),
    goals: goals.map((entry) => ({
      id: entry.id,
      title: entry.title,
      targetAmount: toNumber(entry.targetAmount),
      currentAmount: toNumber(entry.currentAmount),
      status: entry.status,
      startDate: entry.startDate,
      endDate: entry.endDate,
    })),
    withdrawals: withdrawals.map((entry) => ({
      id: entry.id,
      reference: entry.reference,
      amount: toNumber(entry.amount),
      status: entry.status,
      requestedAt: entry.requestedAt,
      paidAt: entry.paidAt,
      cancelledAt: entry.cancelledAt,
    })),
    balanceHistory: balanceHistory.map((entry) => ({
      id: entry.id,
      type: entry.type,
      amount: toNumber(entry.amount),
      label: entry.label,
      isCredit: entry.isCredit,
      occurredAt: entry.occurredAt,
    })),
    tontineHistory: tontineHistory.map((entry) => ({
      id: entry.id,
      type: entry.type,
      amount: toNumber(entry.amount),
      label: entry.label,
      note: entry.note,
      occurredAt: entry.occurredAt,
    })),
  };
}

async function updateClientStatus(userId, payload) {
  const user = await models.User.findByPk(userId, {
    include: [{ model: models.AgentProfile, as: 'agentProfile', required: false }],
  });

  if (!user) {
    throw new AppError('Client introuvable.', 404);
  }
  if (user.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }

  await user.update({
    isActive: Boolean(payload.isActive),
  });

  return {
    id: user.id,
    isActive: user.isActive,
  };
}

async function listAgents(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const search = String(query.search || '').trim();
  const status = String(query.status || '').trim().toLowerCase();

  const whereClause = {};
  if (status === 'active') {
    whereClause.isActive = true;
  } else if (status === 'inactive') {
    whereClause.isActive = false;
  }
  if (search) {
    whereClause[Op.or] = [
      where(fn('LOWER', col('AgentProfile.full_name')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('AgentProfile.agent_code')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
    ];
  }

  const result = await models.AgentProfile.findAndCountAll({
    where: whereClause,
    include: [
      { model: models.User, as: 'user', required: true },
      { model: models.User, as: 'createdClients', required: false },
    ],
    order: [['createdAt', 'DESC']],
    offset,
    limit,
  });

  return {
    items: result.rows.map((entry) => ({
      id: entry.id,
      agentCode: entry.agentCode,
      fullName: entry.fullName,
      isActive: entry.isActive,
      agentBalance: toNumber(entry.agentBalance),
      createdAt: entry.createdAt,
      phoneNumber: entry.user?.phoneNumber || null,
      userId: entry.userId,
      createdClientsCount: entry.createdClients?.length || 0,
    })),
    pagination: {
      page,
      pageSize,
      total: result.count,
    },
  };
}

async function updateAgentStatus(agentId, payload) {
  const agent = await models.AgentProfile.findByPk(agentId, {
    include: [{ model: models.User, as: 'user', required: true }],
  });

  if (!agent) {
    throw new AppError('Agent introuvable.', 404);
  }

  const nextStatus = Boolean(payload.isActive);
  await agent.update({ isActive: nextStatus });
  if (agent.user) {
    await agent.user.update({ isActive: nextStatus });
  }

  return {
    id: agent.id,
    isActive: agent.isActive,
  };
}

async function topUpAgentCash(agentId, payload, requestContext = {}) {
  const agent = await models.AgentProfile.findByPk(agentId, {
    include: [{ model: models.User, as: 'user', required: true }],
  });

  if (!agent) {
    throw new AppError('Agent introuvable.', 404);
  }

  const amount = Number(payload.amount);
  const reason = String(payload.reason || '').trim();

  if (!amount || amount <= 0 || amount % 500 !== 0) {
    throw new AppError(
      "L'approvisionnement admin doit etre un multiple positif de 500.",
      422,
    );
  }

  if (!reason) {
    throw new AppError("Le motif d'approvisionnement est obligatoire.", 422);
  }

  const result = await sequelize.transaction(async (transaction) =>
    applyAgentBalanceChange(
      agent.id,
      {
        amount,
        isCredit: true,
        type: 'topUp',
        label: 'Approvisionnement de caisse par admin',
        note: reason,
        initiatedByUserId: null,
        initiatorType: 'admin',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'admin.agent_cash_topped_up',
        reference: generateCashReference('ADM'),
      },
      transaction,
    ),
  );

  return {
    agent: {
      id: agent.id,
      userId: agent.userId,
      agentCode: agent.agentCode,
      fullName: agent.fullName,
    },
    topUp: {
      reference: result.history.reference,
      amount,
      reason,
      occurredAt: result.history.occurredAt,
      agentBalanceBefore: result.balanceBefore,
      agentBalanceAfter: result.balanceAfter,
      initiatedByAdminUsername: requestContext.adminUsername || null,
    },
  };
}

async function getAgentCashHistory(agentId, query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const agent = await models.AgentProfile.findByPk(agentId, {
    include: [{ model: models.User, as: 'user', required: true }],
  });

  if (!agent) {
    throw new AppError('Agent introuvable.', 404);
  }

  const result = await models.AgentBalanceHistory.findAndCountAll({
    where: { agentProfileId: agentId },
    order: [['occurredAt', 'DESC']],
    offset,
    limit,
  });

  return {
    agent: {
      id: agent.id,
      userId: agent.userId,
      agentCode: agent.agentCode,
      fullName: agent.fullName,
      phoneNumber: agent.user?.phoneNumber || null,
      isActive: agent.isActive,
      agentBalance: toNumber(agent.agentBalance),
      createdAt: agent.createdAt,
    },
    history: {
      items: result.rows.map((entry) => ({
        id: entry.id,
        reference: entry.reference,
        type: entry.type,
        amount: toNumber(entry.amount),
        isCredit: entry.isCredit,
        balanceBefore: toNumber(entry.balanceBefore),
        balanceAfter: toNumber(entry.balanceAfter),
        label: entry.label,
        note: entry.note,
        relatedEntityType: entry.relatedEntityType,
        relatedEntityId: entry.relatedEntityId,
        initiatorType: entry.initiatorType,
        occurredAt: entry.occurredAt,
      })),
      pagination: {
        page,
        pageSize,
        total: result.count,
      },
    },
  };
}

async function reverseProvisioningForAdmin(
  provisioningId,
  payload,
  requestContext = {},
) {
  return reverseProvisioningByAdmin(provisioningId, payload, requestContext);
}

async function listWithdrawals(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const status = String(query.status || '').trim();
  const reference = String(query.reference || '').trim();
  const search = String(query.search || '').trim();

  const whereClause = {};
  if (status) {
    whereClause.status = status;
  }
  if (reference) {
    whereClause.reference = {
      [Op.like]: `%${reference.toUpperCase()}%`,
    };
  }

  const result = await models.Withdrawal.findAndCountAll({
    where: whereClause,
    include: [
      {
        model: models.User,
        as: 'user',
        required: true,
        where: search
          ? {
              [Op.or]: [
                where(fn('LOWER', col('user.display_name')), {
                  [Op.like]: `%${search.toLowerCase()}%`,
                }),
                where(fn('LOWER', col('user.phone_number')), {
                  [Op.like]: `%${search.toLowerCase()}%`,
                }),
              ],
            }
          : undefined,
      },
    ],
    order: [['createdAt', 'DESC']],
    offset,
    limit,
  });

  return {
    items: result.rows.map(serializeWithdrawalEntry),
    pagination: {
      page,
      pageSize,
      total: result.count,
    },
  };
}

async function getWithdrawalDetail(withdrawalId) {
  const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
    include: [{ model: models.User, as: 'user', required: true }],
  });

  if (!withdrawal) {
    throw new AppError('Retrait introuvable.', 404);
  }

  const [wallet, payerAgentProfile, auditLogs] = await Promise.all([
    models.Wallet.findOne({ where: { userId: withdrawal.userId } }),
    withdrawal.paidByAgentProfileId
      ? models.AgentProfile.findByPk(withdrawal.paidByAgentProfileId, {
          include: [{ model: models.User, as: 'user', required: false }],
        })
      : Promise.resolve(null),
    models.AuditLog.findAll({
      where: {
        entityType: 'withdrawal',
        entityId: withdrawal.id,
      },
      include: [{ model: models.User, as: 'user', required: false }],
      order: [['createdAt', 'DESC']],
      limit: 10,
    }),
  ]);

  return {
    withdrawal: {
      ...serializeWithdrawalEntry(withdrawal),
      paidBy: payerAgentProfile
        ? {
            id: payerAgentProfile.user?.id || payerAgentProfile.id,
            displayName:
              payerAgentProfile.user?.displayName || payerAgentProfile.fullName,
            phoneNumber: payerAgentProfile.user?.phoneNumber || null,
            agentCode: payerAgentProfile.agentCode || null,
          }
        : null,
      initiatedByUserId: withdrawal.initiatedByUserId,
      paidByAgentProfileId: withdrawal.paidByAgentProfileId,
      confirmationCodeExpiresAt: withdrawal.confirmationCodeExpiresAt,
      confirmationCodeAttempts: Number(
        withdrawal.confirmationCodeAttempts || 0,
      ),
      isConfirmationCodeExpired:
        new Date(withdrawal.confirmationCodeExpiresAt) < new Date(),
      clientWalletSnapshot: {
        availableBalance: toNumber(wallet?.availableBalance),
        reservedWithdrawalBalance: toNumber(
          wallet?.reservedWithdrawalBalance,
        ),
      },
    },
    auditLogs: auditLogs.map((entry) => ({
      id: entry.id,
      action: entry.action,
      status: entry.status,
      ipAddress: entry.ipAddress,
      createdAt: entry.createdAt,
      user: entry.user
        ? {
            id: entry.user.id,
            displayName: entry.user.displayName,
            phoneNumber: entry.user.phoneNumber,
          }
        : null,
    })),
  };
}

async function getOperationalAnomalies() {
  const now = new Date();
  const staleDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
  const requestedAmountsByUser = await sumRequestedWithdrawalsByUser();

  const [
    staleWithdrawals,
    expiredRequestedWithdrawals,
    walletsWithReservedBalance,
    inactiveAgentsWithCash,
    overdueActiveCycles,
  ] = await Promise.all([
    models.Withdrawal.findAll({
      where: {
        status: 'requested',
        requestedAt: { [Op.lt]: staleDate },
      },
      include: [{ model: models.User, as: 'user', required: true }],
      order: [['requestedAt', 'ASC']],
      limit: 10,
    }),
    models.Withdrawal.findAll({
      where: {
        status: 'requested',
        confirmationCodeExpiresAt: { [Op.lt]: now },
      },
      include: [{ model: models.User, as: 'user', required: true }],
      order: [['confirmationCodeExpiresAt', 'ASC']],
      limit: 10,
    }),
    models.Wallet.findAll({
      where: {
        reservedWithdrawalBalance: { [Op.gt]: 0 },
      },
      include: [{ model: models.User, as: 'user', required: true }],
      order: [['updatedAt', 'DESC']],
    }),
    models.AgentProfile.findAll({
      where: {
        isActive: false,
        agentBalance: { [Op.gt]: 0 },
      },
      include: [{ model: models.User, as: 'user', required: true }],
      order: [['agentBalance', 'DESC']],
      limit: 10,
    }),
    models.TontineCycle.findAll({
      where: {
        status: 'active',
        expectedEndAt: { [Op.lt]: now },
      },
      include: [{ model: models.User, as: 'user', required: true }],
      order: [['expectedEndAt', 'ASC']],
      limit: 10,
    }),
  ]);

  const walletReservationMismatches = walletsWithReservedBalance
    .map((wallet) => {
      const reservedBalance = toNumber(wallet.reservedWithdrawalBalance);
      const requestedAmount =
        requestedAmountsByUser.get(wallet.userId) || 0;

      if (Math.abs(reservedBalance - requestedAmount) < 0.001) {
        return null;
      }

      return {
        userId: wallet.userId,
        client: wallet.user
          ? {
              id: wallet.user.id,
              displayName: wallet.user.displayName,
              phoneNumber: wallet.user.phoneNumber,
            }
          : null,
        reservedBalance,
        requestedAmount,
        gapAmount: reservedBalance - requestedAmount,
      };
    })
    .filter(Boolean)
    .slice(0, 10);

  return {
    counts: {
      staleWithdrawals: staleWithdrawals.length,
      expiredRequestedWithdrawals: expiredRequestedWithdrawals.length,
      walletReservationMismatches: walletReservationMismatches.length,
      inactiveAgentsWithCash: inactiveAgentsWithCash.length,
      overdueActiveCycles: overdueActiveCycles.length,
    },
    staleWithdrawals: staleWithdrawals.map((entry) => ({
      id: entry.id,
      reference: entry.reference,
      amount: toNumber(entry.amount),
      requestedAt: entry.requestedAt,
      client: {
        id: entry.user.id,
        displayName: entry.user.displayName,
        phoneNumber: entry.user.phoneNumber,
      },
    })),
    expiredRequestedWithdrawals: expiredRequestedWithdrawals.map((entry) => ({
      id: entry.id,
      reference: entry.reference,
      amount: toNumber(entry.amount),
      confirmationCodeExpiresAt: entry.confirmationCodeExpiresAt,
      confirmationCodeAttempts: Number(entry.confirmationCodeAttempts || 0),
      client: {
        id: entry.user.id,
        displayName: entry.user.displayName,
        phoneNumber: entry.user.phoneNumber,
      },
    })),
    walletReservationMismatches,
    inactiveAgentsWithCash: inactiveAgentsWithCash.map((entry) => ({
      id: entry.id,
      agentCode: entry.agentCode,
      fullName: entry.fullName,
      phoneNumber: entry.user?.phoneNumber || null,
      agentBalance: toNumber(entry.agentBalance),
    })),
    overdueActiveCycles: overdueActiveCycles.map((entry) => ({
      id: entry.id,
      status: entry.status,
      cumulativeAmount: toNumber(entry.cumulativeAmount),
      expectedEndAt: entry.expectedEndAt,
      client: entry.user
        ? {
            id: entry.user.id,
            displayName: entry.user.displayName,
            phoneNumber: entry.user.phoneNumber,
          }
        : null,
    })),
  };
}

async function listAuditLogs(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const search = String(query.search || '').trim();
  const action = String(query.action || '').trim();

  const whereClause = {};
  if (action) {
    whereClause.action = {
      [Op.like]: `%${action}%`,
    };
  }
  if (search) {
    whereClause[Op.or] = [
      where(fn('LOWER', col('AuditLog.action')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('AuditLog.entity_type')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('user.display_name')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('user.phone_number')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
    ];
  }

  const result = await models.AuditLog.findAndCountAll({
    where: whereClause,
    include: [{ model: models.User, as: 'user', required: false }],
    order: [['createdAt', 'DESC']],
    offset,
    limit,
  });

  return {
    items: result.rows.map((entry) => ({
      id: entry.id,
      action: entry.action,
      entityType: entry.entityType,
      entityId: entry.entityId,
      status: entry.status,
      ipAddress: entry.ipAddress,
      createdAt: entry.createdAt,
      user: entry.user
        ? {
            id: entry.user.id,
            displayName: entry.user.displayName,
            phoneNumber: entry.user.phoneNumber,
          }
        : null,
    })),
    pagination: {
      page,
      pageSize,
      total: result.count,
    },
  };
}

module.exports = {
  getOverview,
  listClients,
  getClientDetail,
  updateClientStatus,
  listAgents,
  updateAgentStatus,
  topUpAgentCash,
  getAgentCashHistory,
  reverseProvisioningForAdmin,
  listWithdrawals,
  getWithdrawalDetail,
  getOperationalAnomalies,
  listAuditLogs,
};
