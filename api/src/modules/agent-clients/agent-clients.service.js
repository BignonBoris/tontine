const bcrypt = require('bcrypt');
const { Op } = require('sequelize');
const crypto = require('node:crypto');
const fsp = require('node:fs/promises');
const path = require('node:path');
const AppError = require('../../common/errors/app-error');
const {
  FINANCIAL_AMOUNT_STEP,
} = require('../../common/constants/finance');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const {
  displayPhone,
  normalizePhone,
  normalizePersonalName,
  isValidPersonalName,
} = require('../auth/auth.service');
const {
  configureStake,
  getCycleOverview,
  hasActiveOrAwaitingCycle,
} = require('../tontine/tontine.service');
const {
  createAgentFundingOperation,
} = require('../agent-provisionings/agent-provisionings.service');
const { closeTontineCycle } = require('../admin/admin.service');

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

async function searchClients(query, type = 'phone') {
  const search = String(query || '').trim();
  const where = {
    isActive: true,
    accountType: { [Op.ne]: 'Agent' },
    '$agentProfile.id$': null,
  };

  if (type === 'name') {
    if (search.length < 2) return [];
    where.displayName = { [Op.like]: `%${search}%` };
  } else {
    const digits = search.replace(/\D/g, '');
    if (digits.length !== 10) return [];
    where.phoneNumber = digits;
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
  const firstName = normalizePersonalName(payload.firstName);
  const lastName = normalizePersonalName(payload.lastName);
  const displayName = `${firstName} ${lastName}`.trim();
  
  const rawPhoneNumber = String(payload.phoneNumber ?? '').trim();
  const address = String(payload.address || '').trim();
  const stakeAmount = Number(payload.stakeAmount);
  const initialDeposit = payload.initialDeposit == null
    ? 0
    : Number(payload.initialDeposit);
  const pinCode = payload.pinCode ? String(payload.pinCode).trim() : null;

  if (!isValidPersonalName(lastName)) {
    throw new AppError('Le nom de famille du client est requis et doit etre valide.', 422);
  }
  if (!isValidPersonalName(firstName)) {
    throw new AppError('Le prenom du client est requis et doit etre valide.', 422);
  }
  const phoneNumber = rawPhoneNumber ? normalizePhone(rawPhoneNumber) : null;
  if (rawPhoneNumber && phoneNumber.length !== 10) {
    throw new AppError('Le numero du client est invalide.', 422);
  }
  if (!pinCode || pinCode.length !== 4 || !/^\d{4}$/.test(pinCode)) {
    throw new AppError('Un code PIN a 4 chiffres est requis.', 422);
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
  if (initialDeposit < 0 || initialDeposit % FINANCIAL_AMOUNT_STEP !== 0) {
    throw new AppError(
      `Le premier depot doit etre vide ou un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }

  if (phoneNumber) {
    const existingUser = await models.User.findOne({ where: { phoneNumber } });
    if (existingUser) {
      throw new AppError('Un client existe deja avec ce numero.', 409);
    }
  }

  const hashedPin = await bcrypt.hash(pinCode, 10);

  const client = await sequelize.transaction(async (transaction) => {
    const createdClient = await models.User.create(
      {
        phoneNumber,
        displayName,
        firstName,
        lastName,
        address,
        accountType: 'Personnel',
        isActive: true,
        createdByAgentProfileId: agentProfile.id,
      },
      { transaction },
    );

    await models.UserPreference.create(
      { 
        userId: createdClient.id,
        pinEnabled: true,
        pinCode: hashedPin
      },
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
  if (initialDeposit < 0 || initialDeposit % FINANCIAL_AMOUNT_STEP !== 0) {
    throw new AppError(
      `Le premier depot doit etre vide ou un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
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

async function closeClientTontine(agentProfile, clientId, payload, requestContext = {}) {
  const pinCode = payload.pinCode ? String(payload.pinCode).trim() : null;

  if (!pinCode || pinCode.length !== 4 || !/^\d{4}$/.test(pinCode)) {
    throw new AppError('Un code PIN a 4 chiffres est requis.', 422);
  }

  const client = await models.User.findOne({
    where: {
      id: clientId,
      isActive: true,
      accountType: { [Op.ne]: 'Agent' },
      createdByAgentProfileId: agentProfile.id,
    },
    include: [{ model: models.UserPreference, as: 'preferences' }]
  });

  if (!client) {
    throw new AppError('Client introuvable dans votre portefeuille.', 404);
  }

  if (!client.preferences || !client.preferences.pinEnabled || !client.preferences.pinCode) {
    throw new AppError("Le client n'a pas de code PIN configure.", 422);
  }

  const pinMatches = await bcrypt.compare(pinCode, client.preferences.pinCode);
  if (!pinMatches) {
    throw new AppError('Code PIN incorrect. Cloture refusee.', 401);
  }

  // Find active or pending-closure tontine cycle
  const activeCycle = await models.TontineCycle.findOne({
    where: {
      userId: client.id,
      status: { [Op.in]: ['active', 'enAttenteValidationFin'] },
    },
  });

  if (!activeCycle) {
    throw new AppError("Le client n'a aucune tontine active ou en attente de cloture.", 422);
  }

  const actorContext = {
    ...requestContext,
    initiatedByUserId: agentProfile.userId,
    initiatorType: 'agent',
  };

  // Close the cycle
  await closeTontineCycle(activeCycle.id, actorContext);

  await writeAuditLog({
    userId: agentProfile.userId,
    action: 'agent.client_tontine_closed',
    entityType: 'client',
    entityId: client.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      tontineCycleId: activeCycle.id,
    },
  });

  return getMyClientDetail(agentProfile.id, client.id);
}

const PRIVATE_KYC_ROOT = path.join(__dirname, '../../private-storage/kyc');
const DOCUMENT_TYPES = new Set(['cni', 'passport', 'residence_permit']);

async function uploadClientKyc(agentProfile, clientId, payload, files, requestContext = {}) {
  if (!files || !files.front || !files.selfie) {
    throw new AppError('Les documents requis (recto, selfie) sont manquants.', 400);
  }

  const documentType = payload.documentType;
  const countryCode = payload.countryCode || 'BJ';
  const documentNumber = payload.documentNumber;

  if (!DOCUMENT_TYPES.has(documentType)) {
    throw new AppError('Type de document invalide.', 422);
  }

  const client = await models.User.findOne({
    where: {
      id: clientId,
      createdByAgentProfileId: agentProfile.id,
      isActive: true,
      accountType: { [Op.ne]: 'Agent' },
    },
  });

  if (!client) {
    throw new AppError('Client introuvable.', 404);
  }

  const [kycCase] = await models.KycCase.findOrCreate({
    where: { userId: client.id },
    defaults: { userId: client.id, status: 'unverified', level: 'basic' },
  });

  if (kycCase.status === 'pending_review') {
    throw new AppError('Ce client a deja un dossier KYC en cours de verification.', 409);
  }

  await fsp.mkdir(PRIVATE_KYC_ROOT, { recursive: true });

  const saveFile = async (fileBuffer, originalName, mimeType, docTypeParam) => {
    if (!fileBuffer) return null;
    const fileId = crypto.randomUUID();
    const ext = mimeType === 'image/png' ? '.png' : mimeType === 'application/pdf' ? '.pdf' : '.jpg';
    const storageKey = `${fileId}${ext}`;
    const absolutePath = path.join(PRIVATE_KYC_ROOT, storageKey);
    
    await fsp.writeFile(absolutePath, fileBuffer);
    const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');

    return {
      storageKey,
      metadata: { contentType: mimeType, size: fileBuffer.length, sha256: hash },
      documentType: docTypeParam
    };
  };

  const docsToSave = [];
  docsToSave.push(await saveFile(files.front[0].buffer, files.front[0].originalname, files.front[0].mimetype, documentType));
  if (files.back && files.back[0]) {
    docsToSave.push(await saveFile(files.back[0].buffer, files.back[0].originalname, files.back[0].mimetype, documentType + '_back'));
  }
  docsToSave.push(await saveFile(files.selfie[0].buffer, files.selfie[0].originalname, files.selfie[0].mimetype, 'selfie'));

  await sequelize.transaction(async (transaction) => {
    for (const doc of docsToSave) {
      if (!doc) continue;
      await models.KycDocument.create({
        kycCaseId: kycCase.id,
        documentType: doc.documentType,
        countryCode,
        documentNumber: documentNumber || 'UNKNOWN',
        storageKey: doc.storageKey,
        metadata: doc.metadata
      }, { transaction });
    }

    kycCase.status = 'pending_review';
    kycCase.submittedAt = new Date();
    await kycCase.save({ transaction });

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.client_kyc_submitted',
      entityType: 'kycCase',
      entityId: kycCase.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      transaction,
    });
  });

  return { success: true, status: 'pending_review' };
}

async function updatePhone(agentProfile, clientId, payload, requestContext = {}) {
  const rawPhoneNumber = String(payload.phoneNumber ?? '').trim();
  if (!rawPhoneNumber) throw new AppError('Le numero de telephone est requis.', 422);
  const phoneNumber = normalizePhone(rawPhoneNumber);
  if (phoneNumber.length !== 10) throw new AppError('Le numero du client est invalide.', 422);

  const client = await models.User.findOne({
    where: { id: clientId, createdByAgentProfileId: agentProfile.id }
  });
  if (!client) throw new AppError('Client introuvable.', 404);

  const existingUser = await models.User.findOne({ where: { phoneNumber } });
  if (existingUser && existingUser.id !== client.id) {
    throw new AppError('Un client existe deja avec ce numero.', 409);
  }

  const oldPhone = client.phoneNumber;
  client.phoneNumber = phoneNumber;
  await client.save();

  await writeAuditLog({
    userId: agentProfile.userId,
    action: 'agent.client_phone_updated',
    entityType: 'client',
    entityId: client.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: { oldPhone, newPhone: phoneNumber },
  });

  return _formatClientDetail(client);
}

module.exports = {
  searchClients,
  listMyClients,
  getMyClientDetail,
  createClient,
  startClientTontine,
  closeClientTontine,
  uploadClientKyc,
  updatePhone,
};
