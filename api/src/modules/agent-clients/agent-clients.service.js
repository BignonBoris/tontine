const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone, normalizePhone } = require('../auth/auth.service');
const {
  configureStake,
  getCycleOverview,
  hasActiveOrAwaitingCycle,
} = require('../tontine/tontine.service');
const {
  createAgentFundingOperation,
} = require('../agent-provisionings/agent-provisionings.service');

function serializeClientBase(client, extras = {}) {
  return {
    id: client.id,
    displayName: client.displayName,
    phoneNumber: displayPhone(client.phoneNumber),
    accountType: client.accountType,
    address: client.address,
    memberSince: client.memberSince,
    lastLoginAt: client.lastLoginAt,
    ...extras,
  };
}

async function buildClientSummary(client) {
  const [cycleOverview, lastOperation] = await Promise.all([
    getCycleOverview(client.id),
    models.TontineHistory.findOne({
      where: { userId: client.id },
      order: [['occurredAt', 'DESC']],
    }),
  ]);

  const cycle = cycleOverview.cycle;
  return serializeClientBase(client, {
    hasActiveTontine: Boolean(
      cycle && ['active', 'enAttenteValidationFin'].includes(cycle.status),
    ),
    currentStakeAmount: cycle?.stakeAmount || 0,
    cycleStatus: cycle?.status || null,
    lastOperationAt: lastOperation?.occurredAt || null,
  });
}

async function searchClients(query) {
  const search = String(query || '').trim();
  const where = {
    isActive: true,
    accountType: { [Op.ne]: 'Agent' },
    '$agentProfile.id$': null,
  };

  if (search.length > 0) {
    const digits = search.replace(/\D/g, '');
    where[Op.or] = [
      { displayName: { [Op.like]: `%${search}%` } },
      { phoneNumber: { [Op.like]: `%${digits}%` } },
    ];
  }

  const clients = await models.User.findAll({
    where,
    include: [
      { model: models.AgentProfile, as: 'agentProfile', required: false },
    ],
    order: [['displayName', 'ASC']],
    limit: 50,
  });

  return Promise.all(clients.map((client) => buildClientSummary(client)));
}

async function listMyClients(agentProfileId, query, filter = 'all') {
  const search = String(query || '').trim();
  const where = {
    isActive: true,
    accountType: { [Op.ne]: 'Agent' },
    createdByAgentProfileId: agentProfileId,
  };

  if (search.length > 0) {
    const digits = search.replace(/\D/g, '');
    where[Op.or] = [
      { displayName: { [Op.like]: `%${search}%` } },
      { phoneNumber: { [Op.like]: `%${digits}%` } },
      { address: { [Op.like]: `%${search}%` } },
    ];
  }

  const clients = await models.User.findAll({
    where,
    order: [['createdAt', 'DESC']],
    limit: 100,
  });

  const summaries = await Promise.all(
    clients.map((client) => buildClientSummary(client)),
  );

  if (filter === 'active') {
    return summaries.filter((client) => client.hasActiveTontine);
  }
  if (filter === 'inactive') {
    return summaries.filter((client) => !client.hasActiveTontine);
  }
  return summaries;
}

async function getMyClientDetail(agentProfileId, clientId) {
  const client = await models.User.findOne({
    where: {
      id: clientId,
      createdByAgentProfileId: agentProfileId,
      isActive: true,
      accountType: { [Op.ne]: 'Agent' },
    },
  });

  if (!client) {
    throw new AppError('Client introuvable dans votre portefeuille.', 404);
  }

  const [summary, wallet, provisionings] = await Promise.all([
    buildClientSummary(client),
    models.Wallet.findOne({ where: { userId: client.id } }),
    models.Provisioning.findAll({
      where: { clientUserId: client.id },
      order: [['createdAt', 'DESC']],
      limit: 10,
    }),
  ]);

  return {
    ...summary,
    availableBalance: Number(wallet?.availableBalance || 0),
    tontineBalance: Number(wallet?.tontineBalance || 0),
    latestProvisionings: provisionings.map((item) => ({
      id: item.id,
      reference: item.reference,
      amount: Number(item.amount),
      status: item.status,
      createdAt: item.createdAt,
      validatedAt: item.validatedAt,
    })),
  };
}

async function createClient(agentProfile, payload, requestContext = {}) {
  const displayName = String(payload.displayName || '').trim();
  const rawPhoneNumber = String(payload.phoneNumber || '').trim();
  const address = String(payload.address || '').trim();
  const stakeAmount = Number(payload.stakeAmount);
  const initialDeposit = payload.initialDeposit == null
    ? 0
    : Number(payload.initialDeposit);

  if (!displayName || displayName.length < 3) {
    throw new AppError('Le nom du client est requis.', 422);
  }
  const phoneNumber = normalizePhone(rawPhoneNumber);
  if (phoneNumber.length !== 8) {
    throw new AppError('Le numero du client est invalide.', 422);
  }
  if (!address || address.length < 3) {
    throw new AppError("L'adresse du client est requise.", 422);
  }
  if (!stakeAmount || stakeAmount <= 0 || stakeAmount % 500 !== 0) {
    throw new AppError('La mise doit etre un multiple positif de 500.', 422);
  }
  if (initialDeposit < 0 || initialDeposit % 500 !== 0) {
    throw new AppError(
      'Le premier depot doit etre vide ou un multiple positif de 500.',
      422,
    );
  }

  const existingUser = await models.User.findOne({ where: { phoneNumber } });
  if (existingUser) {
    throw new AppError('Un client existe deja avec ce numero.', 409);
  }

  const client = await sequelize.transaction(async (transaction) => {
    const createdClient = await models.User.create(
      {
        phoneNumber,
        displayName,
        address,
        accountType: 'Personnel',
        isActive: true,
        createdByAgentProfileId: agentProfile.id,
      },
      { transaction },
    );

    await models.UserPreference.create(
      { userId: createdClient.id },
      { transaction },
    );
    await models.Wallet.create({ userId: createdClient.id }, { transaction });

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.client_created',
      entityType: 'client',
      entityId: createdClient.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        phoneNumber,
        stakeAmount,
        initialDeposit,
      },
      transaction,
    });

    return createdClient;
  });

  const actorContext = {
    ...requestContext,
    initiatedByUserId: agentProfile.userId,
    initiatorType: 'agent',
  };

  await configureStake(client.id, stakeAmount, actorContext);
  if (initialDeposit > 0) {
    await createAgentFundingOperation(
      agentProfile,
      {
        clientUserId: client.id,
        amount: initialDeposit,
        notes: 'Premier depot a la creation client',
      },
      actorContext,
    );
  }

  return getMyClientDetail(agentProfile.id, client.id);
}

async function startClientTontine(agentProfile, clientId, payload, requestContext = {}) {
  const stakeAmount = Number(payload.stakeAmount);
  const initialDeposit = payload.initialDeposit == null
    ? 0
    : Number(payload.initialDeposit);

  if (!stakeAmount || stakeAmount <= 0 || stakeAmount % 500 !== 0) {
    throw new AppError('La mise doit etre un multiple positif de 500.', 422);
  }
  if (initialDeposit < 0 || initialDeposit % 500 !== 0) {
    throw new AppError(
      'Le premier depot doit etre vide ou un multiple positif de 500.',
      422,
    );
  }

  const client = await models.User.findOne({
    where: {
      id: clientId,
      isActive: true,
      accountType: { [Op.ne]: 'Agent' },
    },
    include: [{ model: models.AgentProfile, as: 'agentProfile', required: false }],
  });

  if (!client || client.agentProfile) {
    throw new AppError('Client introuvable ou invalide.', 404);
  }

  const hasCycle = await hasActiveOrAwaitingCycle(client.id);
  if (hasCycle) {
    throw new AppError('Ce client a deja une tontine active.', 409);
  }

  const actorContext = {
    ...requestContext,
    initiatedByUserId: agentProfile.userId,
    initiatorType: 'agent',
  };

  await configureStake(client.id, stakeAmount, actorContext);
  if (initialDeposit > 0) {
    await createAgentFundingOperation(
      agentProfile,
      {
        clientUserId: client.id,
        amount: initialDeposit,
        notes: 'Premier depot au demarrage tontine',
      },
      actorContext,
    );
  }

  await writeAuditLog({
    userId: agentProfile.userId,
    action: 'agent.client_tontine_started',
    entityType: 'client',
    entityId: client.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      stakeAmount,
      initialDeposit,
    },
  });

  if (client.createdByAgentProfileId === agentProfile.id) {
    return getMyClientDetail(agentProfile.id, client.id);
  }

  return buildClientSummary(client);
}

module.exports = {
  searchClients,
  listMyClients,
  getMyClientDetail,
  createClient,
  startClientTontine,
};
