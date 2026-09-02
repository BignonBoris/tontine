const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const { Op, fn, col, where } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const {
  FINANCIAL_AMOUNT_STEP,
} = require('../../common/constants/finance');
const { models, sequelize } = require('../../database/models');
const env = require('../../config/env');
const {
  applyAgentBalanceChange,
  generateCashReference,
} = require('../agent-cash/agent-cash.service');
const {
  reverseProvisioningByAdmin,
} = require('../agent-provisionings/agent-provisionings.service');
const {
  normalizePhone,
  normalizeDisplayName,
  isValidDisplayName,
} = require('../auth/auth.service');
const {
  configureStake,
  depositToCycle,
  hasActiveOrAwaitingCycle,
  reverseTontineDepositByAdmin,
} = require('../tontine/tontine.service');
const {
  createWithdrawalReserve,
} = require('../commission/commission.service');
const {
  createWithdrawal: createClientWithdrawal,
  approveWithdrawalByAdmin,
  rejectWithdrawalByAdmin,
  markWithdrawalPaidByAdmin,
} = require('../withdrawals/withdrawals.service');
const { writeAuditLog } = require('../../common/services/audit-log.service');

const ONGOING_TONTINE_STATUSES = ['active', 'enAttenteValidationFin'];
const ACTIVE_GOAL_STATUS = 'active';
const BUSINESS_TIME_ZONE = 'Africa/Lagos';
const BUSINESS_DAY_FORMATTER = new Intl.DateTimeFormat('en-CA', {
  timeZone: BUSINESS_TIME_ZONE,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

function buildNonAgentClientCondition() {
  return sequelize.literal(`NOT EXISTS (
    SELECT 1
    FROM \`agent_profiles\` AS ap
    WHERE ap.\`user_id\` = \`User\`.\`id\`
  )`);
}

function buildOngoingTontineExistsCondition() {
  return sequelize.literal(`EXISTS (
    SELECT 1
    FROM \`tontine_cycles\` AS tc
    WHERE tc.\`user_id\` = \`User\`.\`id\`
      AND tc.\`status\` IN ('active', 'enAttenteValidationFin')
  )`);
}

function buildOngoingTontineAbsenceCondition() {
  return sequelize.literal(`NOT EXISTS (
    SELECT 1
    FROM \`tontine_cycles\` AS tc
    WHERE tc.\`user_id\` = \`User\`.\`id\`
      AND tc.\`status\` IN ('active', 'enAttenteValidationFin')
  )`);
}

function getBusinessDayNumber(date) {
  const parts = BUSINESS_DAY_FORMATTER.formatToParts(new Date(date));
  const mappedParts = parts.reduce((acc, part) => {
    if (part.type !== 'literal') {
      acc[part.type] = Number(part.value);
    }
    return acc;
  }, {});

  return Math.floor(
    Date.UTC(mappedParts.year, mappedParts.month - 1, mappedParts.day) /
      (24 * 60 * 60 * 1000),
  );
}

function getBusinessCalendarDayCount(startDate, endDate = new Date()) {
  const diff = getBusinessDayNumber(endDate) - getBusinessDayNumber(startDate);
  return Math.max(diff + 1, 1);
}

function buildOverdueCycleCondition() {
  return sequelize.literal(`TIMESTAMPDIFF(
    DAY,
    DATE(\`TontineCycle\`.\`started_at\`),
    CURDATE()
  ) + 1 > FLOOR(
    \`TontineCycle\`.\`cumulative_amount\` / NULLIF(\`TontineCycle\`.\`stake_amount\`, 0)
  )`);
}

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

function computeClientFinancialStats({
  availableBalance,
  ongoingTontineAmount,
  coffersAmount,
}) {
  const normalizedAvailableBalance = toNumber(availableBalance);
  const normalizedOngoingTontineAmount = toNumber(ongoingTontineAmount);
  const normalizedCoffersAmount = toNumber(coffersAmount);

  return {
    availableBalance: normalizedAvailableBalance,
    ongoingTontineAmount: normalizedOngoingTontineAmount,
    estimatedBalance:
      normalizedAvailableBalance + normalizedOngoingTontineAmount,
    coffersAmount: normalizedCoffersAmount,
  };
}

function canUpdateUnstartedTontineCycle(cycle) {
  return (
    ['nonConfiguree', 'active'].includes(cycle.status) &&
    toNumber(cycle.cumulativeAmount) <= 0
  );
}

function serializeTontineCycleListItem(entry) {
  const stakeAmount = toNumber(entry.stakeAmount);
  const cumulativeAmount = toNumber(entry.cumulativeAmount);

  return {
    id: entry.id,
    stakeAmount,
    cumulativeAmount,
    targetAmount: stakeAmount * 31,
    progress:
      stakeAmount > 0
        ? Math.min(cumulativeAmount / (stakeAmount * 31), 1)
        : 0,
    status: entry.status,
    startedAt: entry.startedAt,
    expectedEndAt: entry.expectedEndAt,
    endedAt: entry.endedAt,
    createdAt: entry.createdAt,
    client: {
      id: entry.user.id,
      displayName: entry.user.displayName,
      phoneNumber: entry.user.phoneNumber,
      tontineBalance: toNumber(entry.user.wallet?.tontineBalance),
    },
  };
}

function serializeOverdueCycleListItem(entry, referenceDate = new Date()) {
  const baseItem = serializeTontineCycleListItem(entry);
  const stakeAmount = toNumber(entry.stakeAmount);
  const cumulativeAmount = toNumber(entry.cumulativeAmount);
  const daysElapsed = getBusinessCalendarDayCount(entry.startedAt, referenceDate);
  const coveredDays = stakeAmount > 0 ? Math.floor(cumulativeAmount / stakeAmount) : 0;
  const expectedAmount = stakeAmount * daysElapsed;
  const lateAmount = Math.max(expectedAmount - cumulativeAmount, 0);
  const lateDays = Math.max(daysElapsed - coveredDays, 0);

  return {
    ...baseItem,
    daysElapsed,
    coveredDays,
    lateDays,
    expectedAmount,
    lateAmount,
    client: {
      ...baseItem.client,
      createdByAgent: entry.user?.creatorAgent
        ? {
            id: entry.user.creatorAgent.id,
            agentCode: entry.user.creatorAgent.agentCode,
            fullName: entry.user.creatorAgent.fullName,
          }
        : null,
    },
  };
}

function buildRecoverySearchCondition(search = '') {
  const normalizedSearch = String(search || '').trim().toLowerCase();

  if (!normalizedSearch) {
    return null;
  }

  const likeValue = sequelize.escape(`%${normalizedSearch}%`);

  return sequelize.literal(`EXISTS (
    SELECT 1
    FROM \`users\` AS u
    WHERE u.\`id\` = \`TontineCycle\`.\`user_id\`
      AND (
        LOWER(u.\`display_name\`) LIKE ${likeValue}
        OR LOWER(u.\`phone_number\`) LIKE ${likeValue}
      )
  )`);
}

function buildRecoveryCycleWhere(search = '') {
  const whereParts = [buildOverdueCycleCondition()];
  const searchCondition = buildRecoverySearchCondition(search);

  if (searchCondition) {
    whereParts.push(searchCondition);
  }

  return {
    status: {
      [Op.in]: ONGOING_TONTINE_STATUSES,
    },
    [Op.and]: whereParts,
  };
}

function buildRecoveryCycleInclude() {
  return [
    {
      model: models.User,
      as: 'user',
      required: true,
      include: [
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
    },
  ];
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
    approvedAt: entry.approvedAt,
    approvedByAdminUsername: entry.approvedByAdminUsername || null,
    paidAt: entry.paidAt,
    paidByAdminUsername: entry.paidByAdminUsername || null,
    cancelledAt: entry.cancelledAt,
    initiatorType: entry.initiatorType,
    cancellationReason: entry.cancellationReason,
    rejectionReason: entry.rejectionReason || null,
    paymentReference: entry.paymentReference || null,
    paymentProofImageUrl: entry.paymentProofImageUrl || null,
    paymentProofUploadedAt: entry.paymentProofUploadedAt || null,
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
    totalOngoingTontineCycles,
    totalOngoingTontineAmount,
    totalCoffersAmount,
    recentAuditLogs,
    totalReservedWithdrawals,
    newClientsSeriesRows,
    withdrawalVolumeSeriesRows,
    withdrawalStatusRows,
  ] = await Promise.all([
    models.User.count({
      where: {
        [Op.and]: [buildNonAgentClientCondition()],
      },
    }),
    models.User.count({
      where: {
        isActive: true,
        [Op.and]: [buildNonAgentClientCondition()],
      },
    }),
    models.AgentProfile.count(),
    models.AgentProfile.count({ where: { isActive: true } }),
    models.Withdrawal.count({ where: { status: 'requested' } }),
    models.Withdrawal.sum('amount', { where: { status: 'requested' } }),
    models.Withdrawal.sum('amount', { where: { status: 'paid' } }),
    models.Wallet.sum('availableBalance'),
    models.AgentProfile.sum('agentBalance'),
    models.TontineCycle.count({
      where: {
        status: {
          [Op.in]: ONGOING_TONTINE_STATUSES,
        },
      },
    }),
    models.TontineCycle.sum('cumulativeAmount', {
      where: {
        status: {
          [Op.in]: ONGOING_TONTINE_STATUSES,
        },
      },
    }),
    models.Goal.sum('currentAmount', {
      where: {
        status: ACTIVE_GOAL_STATUS,
      },
    }),
    models.AuditLog.findAll({
      limit: 8,
      order: [['createdAt', 'DESC']],
      include: [{ model: models.User, as: 'user', required: false }],
    }),
    models.Wallet.sum('reservedWithdrawalBalance'),
    models.User.findAll({
      attributes: [
        [fn('DATE', col('User.created_at')), 'day'],
        [fn('COUNT', col('User.id')), 'count'],
      ],
      where: {
        [Op.and]: [buildNonAgentClientCondition()],
        createdAt: {
          [Op.gte]: firstDay,
        },
      },
      group: [fn('DATE', col('User.created_at'))],
      raw: true,
    }),
    models.Withdrawal.findAll({
      attributes: [
        [fn('DATE', col('Withdrawal.created_at')), 'day'],
        [fn('SUM', col('Withdrawal.amount')), 'totalAmount'],
      ],
      where: {
        createdAt: {
          [Op.gte]: firstDay,
        },
      },
      group: [fn('DATE', col('Withdrawal.created_at'))],
      raw: true,
    }),
    models.Withdrawal.findAll({
      attributes: ['status', [fn('COUNT', col('Withdrawal.id')), 'count']],
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
      totalOngoingTontineCycles: toNumber(totalOngoingTontineCycles),
      totalOngoingTontineAmount: toNumber(totalOngoingTontineAmount),
      totalEstimatedBalance:
        toNumber(totalAvailableBalances) + toNumber(totalOngoingTontineAmount),
      totalCoffersAmount: toNumber(totalCoffersAmount),
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
  const tontineStatus = String(query.tontineStatus || '').trim().toLowerCase();

  const whereClause = {
    [Op.and]: [buildNonAgentClientCondition()],
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

  const include = [
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
  ];

  if (tontineStatus === 'ongoing' || tontineStatus === 'none') {
    whereClause[Op.and].push(
      tontineStatus === 'ongoing'
        ? buildOngoingTontineExistsCondition()
        : buildOngoingTontineAbsenceCondition(),
    );
  }

  const result = await models.User.findAndCountAll({
    where: whereClause,
    distinct: true,
    attributes: {
      include: [
        [
          sequelize.literal(`EXISTS (
            SELECT 1
            FROM \`tontine_cycles\` AS tc
            WHERE tc.\`user_id\` = \`User\`.\`id\`
              AND tc.\`status\` IN ('active', 'enAttenteValidationFin')
          )`),
          'hasActiveTontine',
        ],
      ],
    },
    include,
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
      hasActiveTontine: Boolean(Number(entry.get('hasActiveTontine'))),
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

async function createClient(payload, requestContext = {}) {
  const displayName = normalizeDisplayName(payload.displayName);
  const rawPhoneNumber = String(payload.phoneNumber ?? '').trim();
  const address = String(payload.address || '').trim();
  const stakeAmount = Number(payload.stakeAmount);

  if (!isValidDisplayName(displayName)) {
    throw new AppError('Le nom du client est requis.', 422);
  }
  const phoneNumber = rawPhoneNumber ? normalizePhone(rawPhoneNumber) : null;
  if (rawPhoneNumber && phoneNumber.length !== 10) {
    throw new AppError('Le numero du client est invalide.', 422);
  }
  if (!address || address.length < 3) {
    throw new AppError("L'adresse du client est requise.", 422);
  }
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

  if (phoneNumber) {
    const existingUser = await models.User.findOne({ where: { phoneNumber } });
    if (existingUser) {
      throw new AppError('Un client existe deja avec ce numero.', 409);
    }
  }

  const client = await sequelize.transaction(async (transaction) => {
    const createdClient = await models.User.create(
      {
        phoneNumber,
        displayName,
        address,
        accountType: 'Personnel',
        isActive: true,
        createdByAgentProfileId: payload.agentId || null,
      },
      { transaction },
    );

    await models.UserPreference.create(
      { userId: createdClient.id },
      { transaction },
    );
    await models.Wallet.create({ userId: createdClient.id }, { transaction });

    await writeAuditLog({
      userId: null,
      action: 'admin.client_created',
      entityType: 'client',
      entityId: createdClient.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        phoneNumber,
        stakeAmount,
      },
      transaction,
    });

    return createdClient;
  });

  const actorContext = {
    ...requestContext,
    initiatedByUserId: null,
    initiatorType: 'admin',
  };

  await configureStake(client.id, stakeAmount, actorContext);

  return getClientDetail(client.id);
}

async function updateClient(userId, payload, requestContext = {}) {
  const client = await models.User.findByPk(userId, {
    include: [
      { model: models.AgentProfile, as: 'agentProfile', required: false },
      { model: models.AgentProfile, as: 'creatorAgent', required: false },
    ],
  });

  if (!client) {
    throw new AppError('Client introuvable.', 404);
  }
  if (client.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }

  const nextDisplayName =
    payload.displayName !== undefined
      ? normalizeDisplayName(payload.displayName)
      : client.displayName;
  if (!isValidDisplayName(nextDisplayName)) {
    throw new AppError('Le nom du client est requis.', 422);
  }

  const hasPhoneNumber =
    payload.phoneNumber !== undefined &&
    payload.phoneNumber !== null &&
    String(payload.phoneNumber).trim() !== '';
  const nextPhoneNumber = hasPhoneNumber
    ? normalizePhone(String(payload.phoneNumber || '').trim())
    : client.phoneNumber;
  if (hasPhoneNumber && nextPhoneNumber.length !== 10) {
    throw new AppError('Le numero du client est invalide.', 422);
  }

  const nextAddress =
    payload.address !== undefined
      ? String(payload.address || '').trim()
      : client.address;
  if (payload.address !== undefined && (!nextAddress || nextAddress.length < 3)) {
    throw new AppError("L'adresse du client est requise.", 422);
  }

  const nextAgentId =
    payload.agentId !== undefined
      ? String(payload.agentId || '').trim() || null
      : client.createdByAgentProfileId || null;

  if (hasPhoneNumber && nextPhoneNumber !== client.phoneNumber) {
    const duplicateUser = await models.User.findOne({
      where: {
        phoneNumber: nextPhoneNumber,
        id: {
          [Op.ne]: userId,
        },
      },
    });

    if (duplicateUser) {
      throw new AppError('Un client existe deja avec ce numero.', 409);
    }
  }

  if (nextAgentId) {
    const agent = await models.AgentProfile.findByPk(nextAgentId);
    if (!agent) {
      throw new AppError('Agent introuvable.', 404);
    }
  }

  await sequelize.transaction(async (transaction) => {
    await client.update(
      {
        displayName: nextDisplayName,
        phoneNumber: nextPhoneNumber,
        address: nextAddress,
        createdByAgentProfileId: nextAgentId,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: null,
      action: 'admin.client_updated',
      entityType: 'client',
      entityId: client.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        changes: {
          displayName: {
            before: client.previous('displayName'),
            after: nextDisplayName,
          },
          phoneNumber: {
            before: client.previous('phoneNumber'),
            after: nextPhoneNumber,
          },
          address: {
            before: client.previous('address'),
            after: nextAddress,
          },
          createdByAgentProfileId: {
            before: client.previous('createdByAgentProfileId'),
            after: nextAgentId,
          },
        },
      },
      transaction,
    });
  });

  return getClientDetail(client.id);
}

async function listTontines(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const search = String(query.search || '').trim();
  const status = String(query.status || '').trim().toLowerCase();

  const whereClause = {};
  if (status) {
    whereClause.status = status;
  }

  const userWhere = search
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
    : undefined;

  const result = await models.TontineCycle.findAndCountAll({
    where: whereClause,
    include: [
      {
        model: models.User,
        as: 'user',
        required: true,
        where: userWhere,
        include: [
          {
            model: models.Wallet,
            as: 'wallet',
            required: false,
          },
        ],
      },
    ],
    order: [['createdAt', 'DESC']],
    offset,
    limit,
  });

  const items = result.rows.map(serializeTontineCycleListItem);

  return {
    items,
    pagination: {
      page,
      pageSize,
      total: result.count,
    },
  };
}

async function listRecoveryCycles(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const search = String(query.search || '').trim();
  const whereClause = buildRecoveryCycleWhere(search);
  const include = buildRecoveryCycleInclude();

  const [overdueCycleCount, rows, totalsRow] = await Promise.all([
    models.TontineCycle.count({
      where: whereClause,
      distinct: true,
    }),
    models.TontineCycle.findAll({
      where: whereClause,
      include,
      order: [['startedAt', 'ASC']],
      offset,
      limit,
    }),
    models.TontineCycle.findAll({
      attributes: [
        [
          sequelize.literal('COUNT(DISTINCT `TontineCycle`.`user_id`)'),
          'overdueClients',
        ],
        [
          sequelize.literal(
            'COALESCE(SUM(`TontineCycle`.`stake_amount` * (TIMESTAMPDIFF(DAY, DATE(`TontineCycle`.`started_at`), CURDATE()) + 1)), 0)',
          ),
          'totalExpectedAmount',
        ],
        [
          sequelize.literal(
            'COALESCE(SUM((`TontineCycle`.`stake_amount` * (TIMESTAMPDIFF(DAY, DATE(`TontineCycle`.`started_at`), CURDATE()) + 1)) - `TontineCycle`.`cumulative_amount`), 0)',
          ),
          'totalLateAmount',
        ],
        [
          sequelize.literal(
            'COALESCE(SUM((TIMESTAMPDIFF(DAY, DATE(`TontineCycle`.`started_at`), CURDATE()) + 1) - FLOOR(`TontineCycle`.`cumulative_amount` / NULLIF(`TontineCycle`.`stake_amount`, 0))), 0)',
          ),
          'totalLateDays',
        ],
      ],
      where: whereClause,
      raw: true,
    }),
  ]);

  const totals = totalsRow[0] || {};

  return {
    items: rows.map((entry) => serializeOverdueCycleListItem(entry)),
    pagination: {
      page,
      pageSize,
      total: overdueCycleCount,
    },
    totals: {
      overdueCycles: Number(overdueCycleCount || 0),
      overdueClients: toNumber(totals.overdueClients),
      totalExpectedAmount: toNumber(totals.totalExpectedAmount),
      totalLateAmount: toNumber(totals.totalLateAmount),
      totalLateDays: toNumber(totals.totalLateDays),
    },
  };
}

async function getTontineCalendar(cycleId) {
  const cycle = await models.TontineCycle.findByPk(cycleId, {
    include: [
      {
        model: models.User,
        as: 'user',
        required: true,
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
        ],
      },
    ],
  });

  if (!cycle) {
    throw new AppError('Cycle de tontine introuvable.', 404);
  }
  if (cycle.user?.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }

  const deposits = await models.TontineHistory.findAll({
    where: {
      cycleId,
      type: 'deposit',
    },
    order: [['occurredAt', 'ASC']],
  });

  return {
    cycle: {
      id: cycle.id,
      stakeAmount: toNumber(cycle.stakeAmount),
      cumulativeAmount: toNumber(cycle.cumulativeAmount),
      targetAmount: toNumber(cycle.stakeAmount) * 31,
      progress:
        toNumber(cycle.stakeAmount) > 0
          ? Math.min(
              toNumber(cycle.cumulativeAmount) /
                (toNumber(cycle.stakeAmount) * 31),
              1,
            )
          : 0,
      status: cycle.status,
      startedAt: cycle.startedAt,
      expectedEndAt: cycle.expectedEndAt,
      endedAt: cycle.endedAt,
      client: {
        id: cycle.user.id,
        displayName: cycle.user.displayName,
        phoneNumber: cycle.user.phoneNumber,
        tontineBalance: toNumber(cycle.user.wallet?.tontineBalance),
      },
    },
    deposits: deposits.map((entry) => ({
      id: entry.id,
      amount: toNumber(entry.amount),
      label: entry.label,
      note: entry.note,
      occurredAt: entry.occurredAt,
      initiatedByUserId: entry.initiatedByUserId,
      initiatorType: entry.initiatorType,
    })),
  };
}

async function updateTontineCycle(cycleId, payload, requestContext = {}) {
  const stakeAmount = Number(payload.stakeAmount);
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

  const cycle = await models.TontineCycle.findByPk(cycleId, {
    include: [
      {
        model: models.User,
        as: 'user',
        required: true,
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
        ],
      },
    ],
  });

  if (!cycle) {
    throw new AppError('Cycle de tontine introuvable.', 404);
  }
  if (cycle.user?.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }
  if (!canUpdateUnstartedTontineCycle(cycle)) {
    throw new AppError(
      'Ce cycle a deja demarre et ne peut plus etre modifie.',
      409,
    );
  }

  await sequelize.transaction(async (transaction) => {
    await cycle.update(
      {
        stakeAmount,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: null,
      action: 'admin.tontine_cycle_updated',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        changes: {
          stakeAmount: {
            before: Number(cycle.previous('stakeAmount')),
            after: stakeAmount,
          },
          status: cycle.status,
          cumulativeAmount: Number(cycle.cumulativeAmount),
        },
      },
      transaction,
    });
  });

  return serializeTontineCycleListItem(cycle);
}

async function closeTontineCycle(cycleId, requestContext = {}) {
  const cycle = await models.TontineCycle.findByPk(cycleId, {
    include: [
      {
        model: models.User,
        as: 'user',
        required: true,
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
        ],
      },
    ],
  });

  if (!cycle) {
    throw new AppError('Cycle de tontine introuvable.', 404);
  }
  if (cycle.user?.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }
  if (!['active', 'enAttenteValidationFin'].includes(cycle.status)) {
    throw new AppError('Ce cycle ne peut plus etre cloture.', 409);
  }
  if (cycle.status === 'active' && Number(cycle.cumulativeAmount) <= 0) {
    throw new AppError('Aucun cycle eligible a un arret anticipe.', 409);
  }

  const statusBefore = cycle.status;
  const cumulativeBefore = Number(cycle.cumulativeAmount);
  const stakeAmount = Number(cycle.stakeAmount);
  const isCompletedClosure = statusBefore === 'enAttenteValidationFin';
  const adminActor = {
    ...requestContext,
    initiatedByUserId: null,
    initiatorType: 'admin',
  };

  await sequelize.transaction(async (transaction) => {
    const wallet = await models.Wallet.findOne({
      where: { userId: cycle.userId },
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!wallet) {
      throw new AppError('Portefeuille introuvable.', 404);
    }

    if (isCompletedClosure) {
      const netPayoutAmount = stakeAmount * 30;
      const commissionResult = await createWithdrawalReserve({
        transaction,
        cycle,
        userId: cycle.userId,
        respected: true,
        sourceAmount: netPayoutAmount,
        initiatedByUserId: adminActor.initiatedByUserId,
        initiatorType: adminActor.initiatorType,
        requestContext,
      });

      await wallet.update(
        {
          availableBalance:
            Number(wallet.availableBalance || 0) +
            netPayoutAmount +
            Number(commissionResult.bonusAmount || 0),
          tontineBalance: 0,
        },
        { transaction },
      );

      await models.AvailableBalanceHistory.create(
        {
          userId: cycle.userId,
          type: 'tontinePayout',
          amount: netPayoutAmount,
          label: 'Fin de cycle tontine',
          isCredit: true,
        },
        { transaction },
      );

      if (Number(commissionResult.bonusAmount || 0) > 0) {
        await models.AvailableBalanceHistory.create(
          {
            userId: cycle.userId,
            type: 'tontineBonus',
            amount: Number(commissionResult.bonusAmount),
            label: 'Bonus fidelite tontine',
            isCredit: true,
          },
          { transaction },
        );
      }

      await models.TontineHistory.create(
        {
          userId: cycle.userId,
          cycleId: cycle.id,
          type: 'payoutConfirmed',
          amount: netPayoutAmount,
          label: 'Reversement confirme',
          note: null,
          initiatedByUserId: adminActor.initiatedByUserId || cycle.userId,
          initiatorType: adminActor.initiatorType,
        },
        { transaction },
      );

      await models.TontineArchive.create(
        {
          userId: cycle.userId,
          stakeAmount,
          targetAmount: stakeAmount * 31,
          cumulativeAmount: cumulativeBefore,
          commissionAmount: stakeAmount,
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
          cumulativeAmount: cumulativeBefore,
          endedAt: new Date(),
        },
        { transaction },
      );

      await models.Notification.create(
        {
          userId: cycle.userId,
          type: 'cycle',
          title: 'Reversement confirme',
          message: `${netPayoutAmount} F ajoutes a votre solde disponible.`,
        },
        { transaction },
      );

      await writeAuditLog({
        userId: null,
        action: 'admin.tontine_cycle_closed',
        entityType: 'tontineCycle',
        entityId: cycle.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          adminUsername: requestContext.adminUsername || null,
          clientUserId: cycle.userId,
          closureType: 'completed',
          statusBefore,
          cumulativeAmountBefore: cumulativeBefore,
          netPayoutAmount,
          bonusAmount: Number(commissionResult.bonusAmount || 0),
          reserveAmount: Number(commissionResult.reserve?.initialReservedAmount || 0),
          floatingAmount: Number(commissionResult.floatingAmount || 0),
        },
        transaction,
      });
    } else {
      const netAmount = Math.max(cumulativeBefore - stakeAmount, 0);
      const commissionResult = await createWithdrawalReserve({
        transaction,
        cycle,
        userId: cycle.userId,
        respected: false,
        sourceAmount: netAmount,
        initiatedByUserId: adminActor.initiatedByUserId,
        initiatorType: adminActor.initiatorType,
        requestContext,
      });

      await wallet.update(
        {
          availableBalance: Number(wallet.availableBalance || 0) + netAmount,
          tontineBalance: 0,
        },
        { transaction },
      );

      await models.AvailableBalanceHistory.create(
        {
          userId: cycle.userId,
          type: 'tontineEarlyStop',
          amount: netAmount,
          label: 'Arret anticipe tontine',
          isCredit: true,
        },
        { transaction },
      );

      await models.TontineHistory.create(
        {
          userId: cycle.userId,
          cycleId: cycle.id,
          type: 'earlyStop',
          amount: netAmount,
          label: 'Arret anticipe',
          note: null,
          initiatedByUserId: adminActor.initiatedByUserId || cycle.userId,
          initiatorType: adminActor.initiatorType,
        },
        { transaction },
      );

      await models.TontineArchive.create(
        {
          userId: cycle.userId,
          stakeAmount,
          targetAmount: stakeAmount * 31,
          cumulativeAmount: cumulativeBefore,
          commissionAmount: stakeAmount,
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
          cumulativeAmount: cumulativeBefore,
          endedAt: new Date(),
        },
        { transaction },
      );

      await models.Notification.create(
        {
          userId: cycle.userId,
          type: 'cycle',
          title: 'Tontine arretee',
          message: `${netAmount} F reverses au solde disponible apres penalite.`,
        },
        { transaction },
      );

      await writeAuditLog({
        userId: null,
        action: 'admin.tontine_cycle_closed',
        entityType: 'tontineCycle',
        entityId: cycle.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          adminUsername: requestContext.adminUsername || null,
          clientUserId: cycle.userId,
          closureType: 'stoppedEarly',
          statusBefore,
          cumulativeAmountBefore: cumulativeBefore,
          netAmount,
          penaltyAmount: stakeAmount,
          reserveAmount: Number(commissionResult.reserve?.initialReservedAmount || 0),
          floatingAmount: Number(commissionResult.floatingAmount || 0),
          forfeitedBonusAmount: Number(commissionResult.bonusAmount || 0),
        },
        transaction,
      });
    }

    cycle.user.wallet = wallet;
  });

  return serializeTontineCycleListItem(cycle);
}

async function startTontine(userId, stakeAmount, requestContext = {}) {
  const user = await models.User.findByPk(userId, {
    include: [
      {
        model: models.AgentProfile,
        as: 'agentProfile',
        required: false,
      },
    ],
  });
  if (!user) {
    throw new AppError('Client introuvable.', 404);
  }
  if (user.agentProfile) {
    throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
  }
  if (!user.isActive) {
    throw new AppError('Ce client est inactif.', 422);
  }

  const hasCycle = await hasActiveOrAwaitingCycle(userId);
  if (hasCycle) {
    throw new AppError(
      'Ce client a deja une tontine active ou en attente de reversement.',
      409,
    );
  }

  const actorContext = {
    ...requestContext,
    initiatedByUserId: null,
    initiatorType: 'admin',
  };

  const cycle = await configureStake(userId, stakeAmount, actorContext);

  await writeAuditLog({
    userId: null,
    action: 'admin.client_tontine_started',
    entityType: 'client',
    entityId: userId,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      adminUsername: requestContext.adminUsername || null,
      stakeAmount,
      cycleId: cycle.id,
    },
  });

  return cycle;
}

async function recordClientContribution(userId, amount, requestContext = {}) {
  const normalizedAmount = Number(amount);

  if (
    !normalizedAmount ||
    normalizedAmount <= 0 ||
    normalizedAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `La cotisation doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }

  const client = await sequelize.transaction(async (transaction) => {
    const loadedClient = await models.User.findByPk(userId, {
      include: [
        {
          model: models.AgentProfile,
          as: 'agentProfile',
          required: false,
        },
      ],
      transaction,
    });

    if (!loadedClient) {
      throw new AppError('Client introuvable.', 404);
    }
    if (loadedClient.agentProfile) {
      throw new AppError("Cette fiche correspond a un agent, pas a un client.", 422);
    }
    if (!loadedClient.isActive) {
      throw new AppError('Ce client est inactif.', 422);
    }

    const cycle = await depositToCycle(userId, normalizedAmount, 'external', {
      ...requestContext,
      transaction,
      initiatedByUserId: null,
      initiatorType: 'admin',
    });

    await writeAuditLog({
      userId: null,
      action: 'admin.client_contribution_recorded',
      entityType: 'tontineCycle',
      entityId: cycle.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        clientUserId: loadedClient.id,
        amount: normalizedAmount,
      },
      transaction,
    });

    return loadedClient;
  });

  return getClientDetail(client.id);
}

async function recordClientWithdrawal(userId, amount, requestContext = {}) {
  const normalizedAmount = Number(amount);

  if (
    !normalizedAmount ||
    normalizedAmount <= 0 ||
    normalizedAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `Le montant du retrait doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }

  const withdrawal = await createClientWithdrawal(
    userId,
    { amount: normalizedAmount },
    {
      ...requestContext,
      initiatedByUserId: null,
      initiatorType: 'admin',
    },
  );

  return {
    withdrawal,
    client: await getClientDetail(userId),
  };
}

async function reverseClientContribution(userId, historyId, payload, requestContext = {}) {
  await reverseTontineDepositByAdmin(
    userId,
    historyId,
    payload,
    {
      ...requestContext,
      initiatedByUserId: null,
      initiatorType: 'admin',
    },
  );

  return getClientDetail(userId);
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

  const [
    cycles,
    goals,
    withdrawals,
    balanceHistory,
    tontineHistory,
    ongoingTontineAmount,
    coffersAmount,
  ] =
    await Promise.all([
      models.TontineCycle.findAll({
        where: { userId },
        order: [['createdAt', 'DESC']],
        limit: 5,
      }),
      models.Goal.findAll({
        where: { userId },
        include: [{ model: models.MarketOffer, as: 'linkedOffer', required: false }],
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
      models.TontineCycle.sum('cumulativeAmount', {
        where: {
          userId,
          status: {
            [Op.in]: ONGOING_TONTINE_STATUSES,
          },
        },
      }),
      models.Goal.sum('currentAmount', {
        where: {
          userId,
          status: ACTIVE_GOAL_STATUS,
        },
      }),
    ]);

  const financialStats = computeClientFinancialStats({
    availableBalance: client.wallet?.availableBalance,
    ongoingTontineAmount,
    coffersAmount,
  });
  const reversedTontineHistoryIds = new Set(
    tontineHistory
      .filter((entry) => entry.reversalOfHistoryId)
      .map((entry) => entry.reversalOfHistoryId),
  );
  const reversedBalanceHistoryIds = new Set(
    balanceHistory
      .filter((entry) => entry.reversalOfHistoryId)
      .map((entry) => entry.reversalOfHistoryId),
  );

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
    stats: financialStats,
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
      linkedOfferId: entry.linkedOfferId,
      linkedOffer: entry.linkedOffer
        ? {
            id: entry.linkedOffer.id,
            title: entry.linkedOffer.title,
            category: entry.linkedOffer.category,
            brand: entry.linkedOffer.brand,
          }
        : null,
      quantity: Number(entry.quantity || 1),
      unitPrice: toNumber(entry.unitPrice),
      targetAmount: toNumber(entry.targetAmount),
      currentAmount: toNumber(entry.currentAmount),
      progress: computeGoalProgress(entry.currentAmount, entry.targetAmount),
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
      reversalOfHistoryId: entry.reversalOfHistoryId || null,
      isReversal: Boolean(entry.reversalOfHistoryId),
      isReversed: reversedBalanceHistoryIds.has(entry.id),
      occurredAt: entry.occurredAt,
    })),
    tontineHistory: tontineHistory.map((entry) => ({
      id: entry.id,
      type: entry.type,
      amount: toNumber(entry.amount),
      label: entry.label,
      note: entry.note,
      cycleId: entry.cycleId,
      paymentSource: entry.paymentSource || null,
      linkedProvisioningId: entry.linkedProvisioningId || null,
      availableBalanceHistoryId: entry.availableBalanceHistoryId || null,
      reversalOfHistoryId: entry.reversalOfHistoryId || null,
      isReversal: Boolean(entry.reversalOfHistoryId),
      isReversed: reversedTontineHistoryIds.has(entry.id),
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

  if (
    !amount ||
    amount <= 0 ||
    amount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `L'approvisionnement admin doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
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

function computeGoalProgress(currentAmount, targetAmount) {
  const normalizedTarget = toNumber(targetAmount);
  if (normalizedTarget <= 0) {
    return 0;
  }

  return Math.max(0, Math.min(1, toNumber(currentAmount) / normalizedTarget));
}

function generateMarketOfferId() {
  return `offer-${Date.now()}-${Math.floor(Math.random() * 9000)
    .toString()
    .padStart(4, '0')}`;
}

function decodeHtmlEntities(value) {
  return String(value || '')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'");
}

function sanitizeOfferDescriptionHtml(value) {
  if (!value) {
    return '';
  }

  let html = String(value)
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?>[\s\S]*?<\/style>/gi, '')
    .replace(/<div>/gi, '<p>')
    .replace(/<\/div>/gi, '</p>')
    .replace(/<b>/gi, '<strong>')
    .replace(/<\/b>/gi, '</strong>')
    .replace(/<i>/gi, '<em>')
    .replace(/<\/i>/gi, '</em>')
    .replace(/\son\w+="[^"]*"/gi, '')
    .replace(/\son\w+='[^']*'/gi, '')
    .replace(/\sstyle="[^"]*"/gi, '')
    .replace(/\sstyle='[^']*'/gi, '');

  html = html.replace(
    /<\/?([a-z0-9-]+)(?:\s[^>]*)?>/gi,
    (match, tagName) => {
      const normalizedTag = String(tagName || '').toLowerCase();
      const allowedTags = new Set(['p', 'br', 'strong', 'em', 'u', 'ul', 'ol', 'li']);

      if (!allowedTags.has(normalizedTag)) {
        return '';
      }

      return match.startsWith('</') ? `</${normalizedTag}>` : `<${normalizedTag}>`;
    },
  );

  return html.trim();
}

function convertOfferDescriptionHtmlToText(value) {
  if (!value) {
    return '';
  }

  const text = decodeHtmlEntities(
    String(value)
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n\n')
      .replace(/<\/li>/gi, '\n')
      .replace(/<li>/gi, '• ')
      .replace(/<\/?(ul|ol|p|strong|em|u)>/gi, '')
      .replace(/<[^>]+>/g, ''),
  );

  return text
    .replace(/\r/g, '')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n[ \t]+/g, '\n')
    .trim();
}

function normalizeOfferCategory(value) {
  return String(value || '')
    .trim()
    .replace(/\s+/g, ' ')
    .toUpperCase();
}

function buildMarketplaceUploadUrl(fileName) {
  return `${String(env.appBaseUrl || '').replace(/\/+$/, '')}/uploads/marketplace/${fileName}`;
}

async function persistMarketplaceOfferImage(payload = {}) {
  const imageBase64 = String(payload.imageBase64 || '').trim();
  if (!imageBase64) {
    return null;
  }

  const imageMimeType = String(payload.imageMimeType || '').trim().toLowerCase();
  const allowedMimeTypes = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  const extension = allowedMimeTypes[imageMimeType];
  if (!extension) {
    throw new AppError("Le format d'image doit etre JPG, PNG ou WEBP.", 422);
  }

  const buffer = Buffer.from(imageBase64, 'base64');
  if (!buffer.length) {
    throw new AppError("Le fichier image de l'article est vide.", 422);
  }
  if (buffer.length > 5 * 1024 * 1024) {
    throw new AppError("L'image de l'article ne doit pas depasser 5 Mo.", 422);
  }

  const uploadDirectory = path.join(
    __dirname,
    '..',
    '..',
    'public',
    'uploads',
    'marketplace',
  );
  await fs.mkdir(uploadDirectory, { recursive: true });

  const fileName = `offer-${Date.now()}-${crypto.randomBytes(6).toString('hex')}.${extension}`;
  await fs.writeFile(path.join(uploadDirectory, fileName), buffer);

  return buildMarketplaceUploadUrl(fileName);
}

function normalizeOfferPayload(payload = {}) {
  const normalizedDescriptionHtml = sanitizeOfferDescriptionHtml(payload.descriptionHtml);
  const normalizedDescription =
    convertOfferDescriptionHtmlToText(normalizedDescriptionHtml) ||
    String(payload.description || '').trim();

  return {
    title: String(payload.title || '').trim(),
    description: normalizedDescription,
    descriptionHtml: normalizedDescriptionHtml || null,
    imageUrl: String(payload.imageUrl || '').trim(),
    category: normalizeOfferCategory(payload.category),
    brand: payload.brand == null ? null : String(payload.brand).trim(),
    price: Number(payload.price),
  };
}

function validateOfferPayload(payload) {
  if (!payload.title || payload.title.length < 3) {
    throw new AppError("Le titre de l'article est invalide.", 422);
  }
  if (!payload.description || payload.description.length < 8) {
    throw new AppError("La description de l'article est invalide.", 422);
  }
  if (
    !payload.imageUrl ||
    !/^(https?:\/\/|\/uploads\/marketplace\/)/i.test(payload.imageUrl)
  ) {
    throw new AppError("L'image de l'article est invalide.", 422);
  }
  if (!payload.category || payload.category.length < 2) {
    throw new AppError("La categorie de l'article est invalide.", 422);
  }
  if (!payload.price || payload.price <= 0) {
    throw new AppError("Le prix de l'article est invalide.", 422);
  }
}

async function reverseProvisioningForAdmin(
  provisioningId,
  payload,
  requestContext = {},
) {
  return reverseProvisioningByAdmin(provisioningId, payload, requestContext);
}

function parseOperationDate(value, endOfDay = false) {
  const rawValue = String(value || '').trim();
  if (!rawValue) {
    return null;
  }

  const dateValue = rawValue.includes('T')
    ? new Date(rawValue)
    : new Date(`${rawValue}T${endOfDay ? '23:59:59.999' : '00:00:00'}`);

  if (Number.isNaN(dateValue.getTime())) {
    return null;
  }

  return dateValue;
}

function buildOperationClientWhere(search) {
  const normalizedSearch = String(search || '').trim();
  if (!normalizedSearch) {
    return undefined;
  }

  const like = `%${normalizedSearch.toLowerCase()}%`;
  return {
    [Op.or]: [
      where(fn('LOWER', col('user.display_name')), {
        [Op.like]: like,
      }),
      where(fn('LOWER', col('user.phone_number')), {
        [Op.like]: like,
      }),
    ],
  };
}

function buildOperationDateWhere(fieldName, dateFrom, dateTo) {
  const whereClause = {};
  const fromDate = parseOperationDate(dateFrom, false);
  const toDate = parseOperationDate(dateTo, true);

  if (fromDate) {
    whereClause[Op.gte] = fromDate;
  }
  if (toDate) {
    whereClause[Op.lte] = toDate;
  }

  return Object.keys(whereClause).length ? { [fieldName]: whereClause } : {};
}

function buildWithdrawalOperationDateWhere(dateFrom, dateTo) {
  const branches = [];
  const requestedWhere = buildOperationDateWhere('requestedAt', dateFrom, dateTo);
  if (Object.keys(requestedWhere).length) {
    branches.push({
      status: 'requested',
      ...requestedWhere,
    });
  }

  const paidWhere = buildOperationDateWhere('paidAt', dateFrom, dateTo);
  if (Object.keys(paidWhere).length) {
    branches.push({
      status: 'paid',
      ...paidWhere,
    });
  }

  return branches.length ? { [Op.or]: branches } : {};
}

function isOperationWithinDateRange(operation, dateFrom, dateTo) {
  const fromDate = parseOperationDate(dateFrom, false);
  const toDate = parseOperationDate(dateTo, true);
  if (!fromDate && !toDate) {
    return true;
  }

  const operationDate = new Date(operation.occurredAt);
  if (Number.isNaN(operationDate.getTime())) {
    return false;
  }

  if (fromDate && operationDate < fromDate) {
    return false;
  }

  if (toDate && operationDate > toDate) {
    return false;
  }

  return true;
}

function serializeDepositOperation(entry, reversedHistoryIds = new Set()) {
  const isReversal = Boolean(entry.reversalOfHistoryId);
  const isReversed = !isReversal && reversedHistoryIds.has(entry.id);

  return {
    id: entry.id,
    type: entry.type,
    reference: entry.id,
    label: entry.label,
    note: entry.note || null,
    amount: toNumber(entry.amount),
    status: isReversal || isReversed ? 'reversed' : 'posted',
    occurredAt: entry.occurredAt,
    initiatorType: entry.initiatorType || null,
    reversalOfHistoryId: entry.reversalOfHistoryId || null,
    isReversal,
    isReversed,
    client: entry.user
      ? {
          id: entry.user.id,
          displayName: entry.user.displayName,
          phoneNumber: entry.user.phoneNumber,
        }
      : null,
  };
}

function serializeWithdrawalOperation(entry) {
  const occurredAt =
    entry.status === 'paid'
      ? entry.paidAt || entry.requestedAt
      : entry.status === 'cancelled'
        ? entry.cancelledAt || entry.requestedAt
        : entry.requestedAt;

  return {
    id: entry.id,
    type: 'withdrawal',
    reference: entry.reference,
    label: `Retrait ${entry.reference}`,
    note: entry.cancellationReason || entry.notes || null,
    amount: toNumber(entry.amount),
    status: entry.status,
    occurredAt,
    initiatorType: entry.initiatorType || null,
    reversalOfHistoryId: null,
    isReversal: false,
    isReversed: false,
    client: entry.user
      ? {
          id: entry.user.id,
          displayName: entry.user.displayName,
          phoneNumber: entry.user.phoneNumber,
        }
      : null,
  };
}

async function listOperations(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const operationType = String(query.type || 'all').trim().toLowerCase();
  const clientSearch = String(query.clientSearch || query.search || '').trim();
  const dateFrom = query.dateFrom || query.fromDate || query.from || '';
  const dateTo = query.dateTo || query.toDate || query.to || '';

  const clientWhere = buildOperationClientWhere(clientSearch);
  const depositWhere = {
    ...buildOperationDateWhere('occurredAt', dateFrom, dateTo),
    type: {
      [Op.in]: ['deposit', 'depositReversal'],
    },
  };
  const withdrawalWhere = {
    status: {
      [Op.in]: ['requested', 'paid'],
    },
    ...buildWithdrawalOperationDateWhere(dateFrom, dateTo),
  };

  const depositQuery =
    operationType === 'withdrawal'
      ? Promise.resolve([])
      : models.TontineHistory.findAll({
          where: depositWhere,
          include: [
            {
              model: models.User,
              as: 'user',
              required: true,
              where: clientWhere,
            },
          ],
          order: [['occurredAt', 'DESC']],
        });

  const withdrawalQuery =
    operationType === 'deposit'
      ? Promise.resolve([])
      : models.Withdrawal.findAll({
          where: withdrawalWhere,
          include: [
            {
              model: models.User,
              as: 'user',
              required: true,
              where: clientWhere,
            },
          ],
          order: [['requestedAt', 'DESC']],
        });

  const [depositRows, withdrawalRows] = await Promise.all([
    depositQuery,
    withdrawalQuery,
  ]);

  const reversedHistoryIds = new Set(
    depositRows
      .filter((entry) => entry.type === 'depositReversal' && entry.reversalOfHistoryId)
      .map((entry) => entry.reversalOfHistoryId),
  );
  const depositItems = depositRows.map((entry) =>
    serializeDepositOperation(entry, reversedHistoryIds),
  );
  const withdrawalItems = withdrawalRows.map(serializeWithdrawalOperation);
  const items = [...depositItems, ...withdrawalItems].sort(
    (left, right) =>
      new Date(right.occurredAt).getTime() - new Date(left.occurredAt).getTime(),
  );
  const filteredItems = items.filter((item) =>
    isOperationWithinDateRange(item, dateFrom, dateTo),
  );

  const totalDeposited = filteredItems.reduce(
    (sum, item) =>
      sum + (item.type === 'depositReversal' ? -Number(item.amount || 0) : item.type === 'deposit' ? Number(item.amount || 0) : 0),
    0,
  );
  const totalWithdrawn = filteredItems.reduce(
    (sum, item) => sum + (item.type === 'withdrawal' ? Number(item.amount || 0) : 0),
    0,
  );

  return {
    items: filteredItems.slice(offset, offset + limit),
    pagination: {
      page,
      pageSize,
      total: filteredItems.length,
    },
    totals: {
      totalDeposited,
      totalWithdrawn,
      totalCash: totalDeposited - totalWithdrawn,
      totalCount: items.length,
    },
  };
}

async function listWithdrawals(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const status = String(query.status || '').trim();
  const reference = String(query.reference || '').trim();
  const search = String(query.search || '').trim();
  const channel = String(query.channel || '').trim();

  const whereClause = {};
  if (status) {
    whereClause.status = status;
  }
  if (channel) {
    whereClause.channel = channel;
  }
  if (reference) {
    whereClause.reference = {
      [Op.like]: `%${reference.toUpperCase()}%`,
    };
  }

  const result = await models.Withdrawal.findAndCountAll({
    where: whereClause,
    distinct: true,
    include: [
      {
        model: models.User,
        as: 'user',
        required: true,
        where: search
          ? {
              [Op.or]: [
                {
                  displayName: {
                    [Op.like]: `%${search}%`,
                  },
                },
                {
                  phoneNumber: {
                    [Op.like]: `%${search}%`,
                  },
                },
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

async function approveWithdrawalForAdmin(
  withdrawalId,
  payload,
  requestContext = {},
) {
  await approveWithdrawalByAdmin(withdrawalId, payload, requestContext);
  return getWithdrawalDetail(withdrawalId);
}

async function rejectWithdrawalForAdmin(
  withdrawalId,
  payload,
  requestContext = {},
) {
  await rejectWithdrawalByAdmin(withdrawalId, payload, requestContext);
  return getWithdrawalDetail(withdrawalId);
}

async function markWithdrawalPaidForAdmin(
  withdrawalId,
  payload,
  requestContext = {},
) {
  await markWithdrawalPaidByAdmin(withdrawalId, payload, requestContext);
  return getWithdrawalDetail(withdrawalId);
}

async function getMarketplaceOverview() {
  const [offers, orders, linkedGoals] = await Promise.all([
    models.MarketOffer.findAll({
      order: [['isActive', 'DESC'], ['createdAt', 'DESC']],
    }),
    models.MarketOrder.findAll({
      order: [['orderedAt', 'DESC']],
    }),
    models.Goal.findAll({
      where: {
        linkedOfferId: {
          [Op.ne]: null,
        },
      },
      include: [{ model: models.MarketOffer, as: 'linkedOffer', required: false }],
      order: [['endDate', 'ASC']],
    }),
  ]);

  const orderSummaries = new Map();
  for (const order of orders) {
    const summary = orderSummaries.get(order.offerId) || {
      totalOrders: 0,
      totalOrderedQuantity: 0,
      inFlightQuantity: 0,
      deliveredQuantity: 0,
      cancelledQuantity: 0,
      pendingQuantity: 0,
      confirmedQuantity: 0,
      readyQuantity: 0,
      lastOrderedAt: null,
    };

    const quantity = Number(order.quantity || 0);
    summary.totalOrders += 1;
    summary.totalOrderedQuantity += quantity;

    if (['pending', 'confirmed', 'ready'].includes(order.status)) {
      summary.inFlightQuantity += quantity;
    }
    if (order.status === 'completed') {
      summary.deliveredQuantity += quantity;
    }
    if (order.status === 'cancelled') {
      summary.cancelledQuantity += quantity;
    }
    if (order.status === 'pending') {
      summary.pendingQuantity += quantity;
    }
    if (order.status === 'confirmed') {
      summary.confirmedQuantity += quantity;
    }
    if (order.status === 'ready') {
      summary.readyQuantity += quantity;
    }

    if (
      order.orderedAt &&
      (!summary.lastOrderedAt ||
        new Date(order.orderedAt).getTime() >
          new Date(summary.lastOrderedAt).getTime())
    ) {
      summary.lastOrderedAt = order.orderedAt;
    }

    orderSummaries.set(order.offerId, summary);
  }

  const goalSummaries = new Map();
  for (const goal of linkedGoals) {
    const summary = goalSummaries.get(goal.linkedOfferId) || {
      totalGoals: 0,
      activeGoals: 0,
      closedGoals: 0,
      plannedQuantity: 0,
      activePlannedQuantity: 0,
      fundedAmount: 0,
      targetAmount: 0,
      nearestEndDate: null,
      farthestEndDate: null,
    };

    const quantity = Number(goal.quantity || 0);
    summary.totalGoals += 1;
    summary.plannedQuantity += quantity;
    summary.fundedAmount += toNumber(goal.currentAmount);
    summary.targetAmount += toNumber(goal.targetAmount);

    if (goal.status === 'active') {
      summary.activeGoals += 1;
      summary.activePlannedQuantity += quantity;

      if (
        goal.endDate &&
        (!summary.nearestEndDate ||
          new Date(goal.endDate).getTime() <
            new Date(summary.nearestEndDate).getTime())
      ) {
        summary.nearestEndDate = goal.endDate;
      }

      if (
        goal.endDate &&
        (!summary.farthestEndDate ||
          new Date(goal.endDate).getTime() >
            new Date(summary.farthestEndDate).getTime())
      ) {
        summary.farthestEndDate = goal.endDate;
      }
    } else if (goal.status === 'closed') {
      summary.closedGoals += 1;
    }

    goalSummaries.set(goal.linkedOfferId, summary);
  }

  const knownOfferIds = new Set([
    ...offers.map((offer) => offer.id),
    ...orderSummaries.keys(),
    ...goalSummaries.keys(),
  ]);

  const items = [...knownOfferIds]
    .map((offerId) => {
      const offer =
        offers.find((entry) => entry.id === offerId) ||
        linkedGoals.find((entry) => entry.linkedOfferId === offerId)?.linkedOffer ||
        null;

      const directOrders = orderSummaries.get(offerId) || {
        totalOrders: 0,
        totalOrderedQuantity: 0,
        inFlightQuantity: 0,
        deliveredQuantity: 0,
        cancelledQuantity: 0,
        pendingQuantity: 0,
        confirmedQuantity: 0,
        readyQuantity: 0,
        lastOrderedAt: null,
      };

      const linkedGoalsSummary = goalSummaries.get(offerId) || {
        totalGoals: 0,
        activeGoals: 0,
        closedGoals: 0,
        plannedQuantity: 0,
        activePlannedQuantity: 0,
        fundedAmount: 0,
        targetAmount: 0,
        nearestEndDate: null,
        farthestEndDate: null,
      };

      return {
        offerId,
        title: offer?.title || `Produit ${offerId}`,
        category: offer?.category || null,
        brand: offer?.brand || null,
        unitPrice: toNumber(offer?.price),
        isActive: Boolean(offer?.isActive),
        directOrders,
        linkedGoals: {
          ...linkedGoalsSummary,
          progressRate:
            linkedGoalsSummary.targetAmount > 0
              ? Number(
                  (
                    linkedGoalsSummary.fundedAmount /
                    linkedGoalsSummary.targetAmount
                  ).toFixed(4),
                )
              : 0,
        },
      };
    })
    .sort((left, right) => {
      const rightDemand =
        right.directOrders.inFlightQuantity +
        right.linkedGoals.activePlannedQuantity;
      const leftDemand =
        left.directOrders.inFlightQuantity +
        left.linkedGoals.activePlannedQuantity;

      if (rightDemand !== leftDemand) {
        return rightDemand - leftDemand;
      }

      return left.title.localeCompare(right.title);
    });

  return {
    totals: {
      offers: items.length,
      activeOffers: items.filter((item) => item.isActive).length,
      inFlightOrderedQuantity: items.reduce(
        (sum, item) => sum + item.directOrders.inFlightQuantity,
        0,
      ),
      activePlannedGoalQuantity: items.reduce(
        (sum, item) => sum + item.linkedGoals.activePlannedQuantity,
        0,
      ),
    },
    items,
  };
}

async function listMarketplaceOffers(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const search = String(query.search || '').trim();
  const status = String(query.status || '').trim().toLowerCase();
  const category = String(query.category || '').trim().toUpperCase();

  const whereClause = {};
  if (status === 'active') {
    whereClause.isActive = true;
  } else if (status === 'inactive') {
    whereClause.isActive = false;
  }
  if (category) {
    whereClause.category = category;
  }
  if (search) {
    whereClause[Op.or] = [
      where(fn('LOWER', col('MarketOffer.title')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('MarketOffer.description')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
      where(fn('LOWER', col('MarketOffer.brand')), {
        [Op.like]: `%${search.toLowerCase()}%`,
      }),
    ];
  }

  const result = await models.MarketOffer.findAndCountAll({
    where: whereClause,
    order: [['createdAt', 'DESC']],
    offset,
    limit,
  });

  return {
    items: result.rows.map((entry) => ({
      id: entry.id,
      title: entry.title,
      description: entry.description,
      descriptionHtml: entry.descriptionHtml,
      imageUrl: entry.imageUrl,
      category: entry.category,
      brand: entry.brand,
      price: toNumber(entry.price),
      isActive: entry.isActive,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    })),
    pagination: {
      page,
      pageSize,
      total: result.count,
    },
  };
}

async function createMarketplaceOffer(payload, requestContext = {}) {
  const uploadedImageUrl = await persistMarketplaceOfferImage(payload);
  const normalized = normalizeOfferPayload({
    ...payload,
    imageUrl: uploadedImageUrl || payload.imageUrl,
  });
  validateOfferPayload(normalized);

  const offer = await models.MarketOffer.create({
    id: generateMarketOfferId(),
    ...normalized,
    isActive: true,
  });

  await writeAuditLog({
    userId: null,
    action: 'admin.marketplace_offer_created',
    entityType: 'marketOffer',
    entityId: offer.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      adminUsername: requestContext.adminUsername || null,
      title: offer.title,
      category: offer.category,
      price: toNumber(offer.price),
    },
  });

  return offer;
}

async function updateMarketplaceOffer(offerId, payload, requestContext = {}) {
  const offer = await models.MarketOffer.findByPk(offerId);
  if (!offer) {
    throw new AppError('Article marketplace introuvable.', 404);
  }

  const uploadedImageUrl = await persistMarketplaceOfferImage(payload);
  const normalized = normalizeOfferPayload({
    ...payload,
    imageUrl: uploadedImageUrl || payload.imageUrl || offer.imageUrl,
  });
  validateOfferPayload(normalized);

  await offer.update(normalized);

  await writeAuditLog({
    userId: null,
    action: 'admin.marketplace_offer_updated',
    entityType: 'marketOffer',
    entityId: offer.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      adminUsername: requestContext.adminUsername || null,
      title: offer.title,
      category: offer.category,
      price: toNumber(offer.price),
    },
  });

  return offer;
}

async function updateMarketplaceOfferStatus(
  offerId,
  payload,
  requestContext = {},
) {
  const offer = await models.MarketOffer.findByPk(offerId);
  if (!offer) {
    throw new AppError('Article marketplace introuvable.', 404);
  }

  await offer.update({ isActive: Boolean(payload.isActive) });

  await writeAuditLog({
    userId: null,
    action: 'admin.marketplace_offer_status_updated',
    entityType: 'marketOffer',
    entityId: offer.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      adminUsername: requestContext.adminUsername || null,
      isActive: offer.isActive,
      title: offer.title,
    },
  });

  return offer;
}

async function listMarketplaceOrders(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const status = String(query.status || '').trim();
  const search = String(query.search || '').trim();
  const offerId = String(query.offerId || '').trim();

  const whereClause = {};
  if (status) {
    whereClause.status = status;
  }
  if (offerId) {
    whereClause.offerId = offerId;
  }

  const result = await models.MarketOrder.findAndCountAll({
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
      {
        model: models.MarketOffer,
        as: 'offer',
        required: false,
      },
    ],
    order: [['orderedAt', 'DESC']],
    offset,
    limit,
  });

  return {
    items: result.rows.map((entry) => ({
      id: entry.id,
      offerId: entry.offerId,
      title: entry.title,
      quantity: Number(entry.quantity || 0),
      unitPrice: toNumber(entry.unitPrice),
      amount: toNumber(entry.amount),
      status: entry.status,
      orderedAt: entry.orderedAt,
      updatedStatusAt: entry.updatedStatusAt,
      offer: entry.offer
        ? {
            id: entry.offer.id,
            title: entry.offer.title,
            category: entry.offer.category,
            brand: entry.offer.brand,
            isActive: entry.offer.isActive,
          }
        : null,
      client: entry.user
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

async function listMarketplaceGoals(query = {}) {
  const { page, pageSize, offset, limit } = parsePagination(query);
  const status = String(query.status || '').trim();
  const search = String(query.search || '').trim();
  const offerId = String(query.offerId || '').trim();

  const whereClause = {
    linkedOfferId: {
      [Op.ne]: null,
    },
  };
  if (status) {
    whereClause.status = status;
  }
  if (offerId) {
    whereClause.linkedOfferId = offerId;
  }

  const result = await models.Goal.findAndCountAll({
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
      {
        model: models.MarketOffer,
        as: 'linkedOffer',
        required: false,
      },
    ],
    order: [['endDate', 'ASC']],
    offset,
    limit,
  });

  return {
    items: result.rows.map((entry) => ({
      id: entry.id,
      title: entry.title,
      linkedOfferId: entry.linkedOfferId,
      quantity: Number(entry.quantity || 0),
      unitPrice: toNumber(entry.unitPrice),
      targetAmount: toNumber(entry.targetAmount),
      currentAmount: toNumber(entry.currentAmount),
      progress: computeGoalProgress(entry.currentAmount, entry.targetAmount),
      status: entry.status,
      startDate: entry.startDate,
      endDate: entry.endDate,
      linkedOffer: entry.linkedOffer
        ? {
            id: entry.linkedOffer.id,
            title: entry.linkedOffer.title,
            category: entry.linkedOffer.category,
            brand: entry.linkedOffer.brand,
            isActive: entry.linkedOffer.isActive,
          }
        : null,
      client: entry.user
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

async function getWithdrawalDetail(withdrawalId) {
  const withdrawal = await models.Withdrawal.findByPk(withdrawalId, {
    include: [{ model: models.User, as: 'user', required: true }],
  });

  if (!withdrawal) {
    throw new AppError('Retrait introuvable.', 404);
  }

  const isAgentCashWithdrawal =
    String(withdrawal.channel || '').trim() === 'agent_cash';

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
      confirmationCodeExpiresAt: isAgentCashWithdrawal
        ? withdrawal.confirmationCodeExpiresAt
        : null,
      confirmationCodeAttempts: isAgentCashWithdrawal
        ? Number(withdrawal.confirmationCodeAttempts || 0)
        : 0,
      isConfirmationCodeExpired: isAgentCashWithdrawal
        ? withdrawal.confirmationCodeExpiresAt != null
          ? new Date(withdrawal.confirmationCodeExpiresAt) < new Date()
          : false
        : false,
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
  const overdueCycleWhere = {
    status: {
      [Op.in]: ONGOING_TONTINE_STATUSES,
    },
    [Op.and]: [buildOverdueCycleCondition()],
  };

  const [
    staleWithdrawals,
    expiredRequestedWithdrawals,
    walletsWithReservedBalance,
    inactiveAgentsWithCash,
    overdueActiveCycles,
    overdueActiveCycleCount,
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
      where: overdueCycleWhere,
      include: buildRecoveryCycleInclude(),
      order: [['startedAt', 'ASC']],
      limit: 10,
    }),
    models.TontineCycle.count({
      where: overdueCycleWhere,
      distinct: true,
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
      overdueActiveCycles: overdueActiveCycleCount,
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

async function getSystemSettings() {
  const settings = await models.SystemSetting.findAll();
  return settings;
}

async function updateSystemSetting(key, payload, requestContext) {
  const setting = await models.SystemSetting.findByPk(key);
  if (!setting) {
    throw new AppError('Parametre introuvable', 404);
  }
  
  if (payload.value === undefined) {
    throw new AppError('La valeur est requise', 422);
  }

  await setting.update({
    value: payload.value,
    description: payload.description || setting.description,
  });

  await writeAuditLog({
    userId: requestContext.userId,
    action: 'system_setting.updated',
    entityType: 'system_setting',
    entityId: key,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      newValue: payload.value,
    },
  });

  return setting;
}

module.exports = {
  getOverview,
  getMarketplaceOverview,
  listMarketplaceOffers,
  createMarketplaceOffer,
  updateMarketplaceOffer,
  updateMarketplaceOfferStatus,
  listMarketplaceOrders,
  listMarketplaceGoals,
  listOperations,
  listClients,
  createClient,
  updateClient,
  listTontines,
  listRecoveryCycles,
  getTontineCalendar,
  updateTontineCycle,
  closeTontineCycle,
  startTontine,
  recordClientContribution,
  recordClientWithdrawal,
  approveWithdrawalForAdmin,
  rejectWithdrawalForAdmin,
  markWithdrawalPaidForAdmin,
  reverseClientContribution,
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
  getSystemSettings,
  updateSystemSetting,
};
