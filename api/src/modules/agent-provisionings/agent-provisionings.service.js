const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const {
  depositToCycle,
  getOpenCycleForFunding,
  hasActiveOrAwaitingCycle,
} = require('../tontine/tontine.service');
const { applyAgentBalanceChange } = require('../agent-cash/agent-cash.service');

function generateReference() {
  return `PRV-${Date.now()}-${Math.floor(Math.random() * 9000)
    .toString()
    .padStart(4, '0')}`;
}

async function listProvisionings(agentProfileId) {
  const provisionings = await models.Provisioning.findAll({
    where: { agentProfileId },
    include: [{ model: models.User, as: 'client' }],
    order: [['createdAt', 'DESC']],
    limit: 50,
  });

  return provisionings.map((item) => ({
    id: item.id,
    reference: item.reference,
    amount: Number(item.amount),
    status: item.status,
    source: item.source,
    notes: item.notes,
    createdAt: item.createdAt,
    validatedAt: item.validatedAt,
    initiatedByUserId: item.initiatedByUserId,
    initiatorType: item.initiatorType,
    client: item.client
      ? {
          id: item.client.id,
          displayName: item.client.displayName,
          phoneNumber: displayPhone(item.client.phoneNumber),
        }
      : null,
  }));
}

async function validateProvisioningRequest(clientUserId, amount) {
  if (!clientUserId) {
    throw new AppError('Le client est requis.', 422);
  }
  if (!amount || amount <= 0 || amount % 500 !== 0) {
    throw new AppError('Le montant doit etre un multiple positif de 500.', 422);
  }
}

async function loadEligibleClient(clientUserId, amount) {
  const client = await models.User.findByPk(clientUserId, {
    include: [{ model: models.AgentProfile, as: 'agentProfile', required: false }],
  });

  if (!client || !client.isActive || client.agentProfile) {
    throw new AppError('Client introuvable ou invalide.', 404);
  }

  const hasCycle = await hasActiveOrAwaitingCycle(client.id);
  if (!hasCycle) {
    throw new AppError(
      "Ce client n'a pas de tontine active pour recevoir un provisioning.",
      409,
    );
  }

  const { remainingAmount } = await getOpenCycleForFunding(client.id);
  if (amount > remainingAmount) {
    throw new AppError(
      `Ce client ne peut plus recevoir que ${remainingAmount} F sur son cycle en cours.`,
      422,
    );
  }

  return client;
}

async function createAgentFundingOperation(
  agentProfile,
  { clientUserId, amount, notes = null },
  requestContext = {},
) {
  await validateProvisioningRequest(clientUserId, amount);

  if (Number(agentProfile.agentBalance || 0) < amount) {
    throw new AppError(
      'Solde de caisse agent insuffisant pour effectuer ce depot.',
      422,
    );
  }

  const client = await loadEligibleClient(clientUserId, amount);

  const provisioning = await sequelize.transaction(async (transaction) => {
    const created = await models.Provisioning.create(
      {
        reference: generateReference(),
        agentProfileId: agentProfile.id,
        clientUserId: client.id,
        amount,
        source: 'agent',
        status: 'validated',
        notes,
        validatedAt: new Date(),
        validatedByUserId: agentProfile.userId,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
      },
      { transaction },
    );

    await depositToCycle(client.id, amount, 'external', {
      ...requestContext,
      transaction,
      initiatedByUserId: agentProfile.userId,
      initiatorType: 'agent',
    });

    const cashChange = await applyAgentBalanceChange(
      agentProfile.id,
      {
        amount,
        isCredit: false,
        type: 'clientDeposit',
        label: `Depot client ${client.displayName}`,
        note: notes,
        relatedEntityType: 'provisioning',
        relatedEntityId: created.id,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'agent.cash_debited_for_client_deposit',
        reference: created.reference,
      },
      transaction,
    );

    await writeAuditLog({
      userId: agentProfile.userId,
      action: 'agent.provisioning_created',
      entityType: 'provisioning',
      entityId: created.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        clientUserId: client.id,
        amount,
        reference: created.reference,
        agentBalanceBefore: cashChange.balanceBefore,
        agentBalanceAfter: cashChange.balanceAfter,
      },
      transaction,
    });

    return { created, agentBalanceAfter: cashChange.balanceAfter, client };
  });

  return provisioning;
}

async function createProvisioning(agentProfile, payload, requestContext = {}) {
  const clientUserId = String(payload.clientUserId || '').trim();
  const amount = Number(payload.amount);
  const notes = payload.notes ? String(payload.notes).trim() : null;

  const provisioning = await createAgentFundingOperation(
    agentProfile,
    { clientUserId, amount, notes },
    requestContext,
  );

  return {
    id: provisioning.created.id,
    reference: provisioning.created.reference,
    amount: Number(provisioning.created.amount),
    status: provisioning.created.status,
    client: {
      id: provisioning.client.id,
      displayName: provisioning.client.displayName,
      phoneNumber: displayPhone(provisioning.client.phoneNumber),
    },
    validatedAt: provisioning.created.validatedAt,
    agentBalance: provisioning.agentBalanceAfter,
  };
}

module.exports = {
  listProvisionings,
  createProvisioning,
  createAgentFundingOperation,
};
