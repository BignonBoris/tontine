const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');
const { Op, fn, col, where } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { models, sequelize } = require('../../database/models');
const env = require('../../config/env');
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
  getMarketplaceOverview,
  listMarketplaceOffers,
  createMarketplaceOffer,
  updateMarketplaceOffer,
  updateMarketplaceOfferStatus,
  listMarketplaceOrders,
  listMarketplaceGoals,
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
