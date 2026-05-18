const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { displayPhone } = require('../auth/auth.service');
const { applyAgentBalanceChange } = require('../agent-cash/agent-cash.service');
const {
  reverseCommissionCredits,
} = require('../commission/commission.service');
const {
  depositToCycle,
  getOpenCycleForFunding,
  hasActiveOrAwaitingCycle,
  reverseProvisioningDepositOnCycle,
} = require('../tontine/tontine.service');

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
    cycleId: item.cycleId,
    amount: Number(item.amount),
    status: item.status,
    source: item.source,
    notes: item.notes,
    createdAt: item.createdAt,
    validatedAt: item.validatedAt,
    reversedAt: item.reversedAt,
    reversedByUserId: item.reversedByUserId,
    reversalReason: item.reversalReason,
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

  const { remainingAmount, cycle } = await getOpenCycleForFunding(client.id);
  if (amount > remainingAmount) {
    throw new AppError(
      `Ce client ne peut plus recevoir que ${remainingAmount} F sur son cycle en cours.`,
      422,
    );
  }

  return { client, cycle, remainingAmount };
}

async function createProvisioning(agentProfile, payload, requestContext = {}) {
  const clientUserId = String(payload?.clientUserId || '').trim();
  const amount = Number(payload?.amount);
  const notes = payload?.notes ? String(payload.notes).trim() : null;

  await validateProvisioningRequest(clientUserId, amount);

  if (Number(agentProfile.agentBalance || 0) < amount) {
    throw new AppError(
      'Solde de caisse agent insuffisant pour effectuer ce depot.',
      422,
    );
  }

  const { client, cycle } = await loadEligibleClient(clientUserId, amount);

  const provisioning = await sequelize.transaction(async (transaction) => {
    const created = await models.Provisioning.create(
      {
        reference: generateReference(),
        agentProfileId: agentProfile.id,
        clientUserId: client.id,
        cycleId: cycle.id,
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
      provisioningId: created.id,
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
        cycleId: cycle.id,
        amount,
        reference: created.reference,
        agentBalanceBefore: cashChange.balanceBefore,
        agentBalanceAfter: cashChange.balanceAfter,
      },
      transaction,
    });

    return { created, agentBalanceAfter: cashChange.balanceAfter, client };
  });

  return {
    id: provisioning.created.id,
    reference: provisioning.created.reference,
    cycleId: provisioning.created.cycleId,
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

async function reverseProvisioningCore(
  {
    provisioningWhere,
    actorUserId = null,
    actorType,
    agentProfileId = null,
    auditAction,
    cashAuditAction,
    requestContext = {},
  },
  provisioningId,
  payload,
) {
  const reason = String(payload?.reason || '').trim();
  if (!reason) {
    throw new AppError('Le motif de correction est requis.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    const provisioning = await models.Provisioning.findOne({
      where: {
        id: provisioningId,
        ...provisioningWhere,
      },
      include: [{ model: models.User, as: 'client' }],
      transaction,
    });

    if (!provisioning) {
      throw new AppError('Provisioning introuvable.', 404);
    }
    if (provisioning.status !== 'validated') {
      throw new AppError(
        'Seul un provisioning valide peut etre contrepasse.',
        409,
      );
    }
    if (!provisioning.cycleId) {
      throw new AppError(
        'Ce provisioning ne contient pas de cycle lie et ne peut pas etre corrige automatiquement.',
        409,
      );
    }

    await reverseProvisioningDepositOnCycle({
      transaction,
      userId: provisioning.clientUserId,
      cycleId: provisioning.cycleId,
      amount: Number(provisioning.amount),
      requestContext: {
        ...requestContext,
        initiatedByUserId: actorUserId,
        initiatorType: actorType,
      },
      note: `Provisioning ${provisioning.reference}: ${reason}`,
    });

    const cashChange = await applyAgentBalanceChange(
      agentProfileId || provisioning.agentProfileId,
      {
        amount: Number(provisioning.amount),
        isCredit: true,
        type: 'clientDeposit',
        label: `Correction depot client ${provisioning.client?.displayName || ''}`.trim(),
        note: reason,
        relatedEntityType: 'provisioning',
        relatedEntityId: provisioning.id,
        initiatedByUserId: actorUserId,
        initiatorType: actorType,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: cashAuditAction,
        reference: `${provisioning.reference}-REV`,
      },
      transaction,
    );

    const commissionReversal = await reverseCommissionCredits({
      transaction,
      sourceType: 'tontine_deposit',
      sourceId: provisioning.id,
      initiatedByUserId: actorUserId,
      initiatorType: actorType,
      reason,
      requestContext,
    });

    const reversedAt = new Date();
    await provisioning.update(
      {
        status: 'cancelled',
        reversedAt,
        reversedByUserId: actorUserId,
        reversalReason: reason,
        notes: provisioning.notes
          ? `${provisioning.notes} | Correction: ${reason}`
          : `Correction: ${reason}`,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: actorUserId,
      action: auditAction,
      entityType: 'provisioning',
      entityId: provisioning.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        reference: provisioning.reference,
        agentProfileId: provisioning.agentProfileId,
        clientUserId: provisioning.clientUserId,
        cycleId: provisioning.cycleId,
        amount: Number(provisioning.amount),
        reason,
        agentBalanceAfter: cashChange.balanceAfter,
        initiatedByAdminUsername: requestContext.adminUsername || null,
        reversedCommissionEntriesCount:
          commissionReversal.reversedEntriesCount,
        reversedCommissionAmount: commissionReversal.totalReversedAmount,
      },
      transaction,
    });

    return {
      id: provisioning.id,
      reference: provisioning.reference,
      amount: Number(provisioning.amount),
      status: 'cancelled',
      reversedAt,
      reversalReason: reason,
      agentBalance: cashChange.balanceAfter,
      client: provisioning.client
        ? {
            id: provisioning.client.id,
            displayName: provisioning.client.displayName,
            phoneNumber: displayPhone(provisioning.client.phoneNumber),
          }
        : null,
      reversedCommissionEntriesCount: commissionReversal.reversedEntriesCount,
      reversedCommissionAmount: commissionReversal.totalReversedAmount,
    };
  });
}

async function reverseProvisioning(
  agentProfile,
  provisioningId,
  payload,
  requestContext = {},
) {
  return reverseProvisioningCore(
    {
      provisioningWhere: {
        agentProfileId: agentProfile.id,
      },
      actorUserId: agentProfile.userId,
      actorType: 'agent',
      agentProfileId: agentProfile.id,
      auditAction: 'agent.provisioning_reversed',
      cashAuditAction: 'agent.cash_recredited_after_provisioning_reversal',
      requestContext,
    },
    provisioningId,
    payload,
  );
}

async function reverseProvisioningByAdmin(
  provisioningId,
  payload,
  requestContext = {},
) {
  return reverseProvisioningCore(
    {
      provisioningWhere: {},
      actorUserId: null,
      actorType: 'admin',
      auditAction: 'admin.provisioning_reversed',
      cashAuditAction: 'admin.agent_cash_recredited_after_provisioning_reversal',
      requestContext,
    },
    provisioningId,
    payload,
  );
}

module.exports = {
  listProvisionings,
  createProvisioning,
  reverseProvisioning,
  reverseProvisioningByAdmin,
};
