const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

function generateCashReference(prefix = 'CSH') {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 9000)
    .toString()
    .padStart(4, '0')}`;
}

async function applyAgentBalanceChange(
  agentProfileId,
  {
    amount,
    isCredit,
    type,
    label,
    note = null,
    relatedEntityType = null,
    relatedEntityId = null,
    initiatedByUserId = null,
    initiatorType = 'system',
    ipAddress = null,
    userAgent = null,
    auditAction = null,
    reference = null,
  },
  transaction,
) {
  if (!transaction) {
    throw new AppError('Transaction requise pour la caisse agent.', 500);
  }

  const normalizedAmount = Number(amount);
  if (!normalizedAmount || normalizedAmount <= 0) {
    throw new AppError('Montant de caisse invalide.', 422);
  }

  const agentProfile = await models.AgentProfile.findByPk(agentProfileId, {
    transaction,
    lock: transaction.LOCK.UPDATE,
  });

  if (!agentProfile || !agentProfile.isActive) {
    throw new AppError('Compte agent invalide ou inactif.', 403);
  }

  const balanceBefore = Number(agentProfile.agentBalance || 0);
  const balanceAfter = isCredit
    ? balanceBefore + normalizedAmount
    : balanceBefore - normalizedAmount;

  if (balanceAfter < 0) {
    throw new AppError('Solde de caisse agent insuffisant.', 422);
  }

  await agentProfile.update({ agentBalance: balanceAfter }, { transaction });

  const history = await models.AgentBalanceHistory.create(
    {
      agentProfileId,
      type,
      reference: reference || generateCashReference('ACH'),
      amount: normalizedAmount,
      isCredit,
      balanceBefore,
      balanceAfter,
      label,
      note,
      relatedEntityType,
      relatedEntityId,
      initiatedByUserId,
      initiatorType,
    },
    { transaction },
  );

  if (auditAction) {
    await writeAuditLog({
      userId: initiatedByUserId,
      action: auditAction,
      entityType: 'agentCash',
      entityId: history.id,
      ipAddress,
      userAgent,
      metadata: {
        agentProfileId,
        amount: normalizedAmount,
        isCredit,
        type,
        balanceBefore,
        balanceAfter,
        reference: history.reference,
        relatedEntityType,
        relatedEntityId,
      },
      transaction,
    });
  }

  return {
    agentProfile,
    history,
    balanceBefore,
    balanceAfter,
  };
}

async function getCashOverview(agentProfileId) {
  const [agentProfile, history] = await Promise.all([
    models.AgentProfile.findByPk(agentProfileId),
    models.AgentBalanceHistory.findAll({
      where: { agentProfileId },
      order: [['occurredAt', 'DESC']],
      limit: 30,
    }),
  ]);

  return {
    agentBalance: Number(agentProfile?.agentBalance || 0),
    history: history.map((item) => ({
      id: item.id,
      reference: item.reference,
      type: item.type,
      amount: Number(item.amount),
      isCredit: item.isCredit,
      balanceBefore: Number(item.balanceBefore),
      balanceAfter: Number(item.balanceAfter),
      label: item.label,
      note: item.note,
      occurredAt: item.occurredAt,
    })),
  };
}

async function topUpCash(agentProfile, payload, requestContext = {}) {
  const amount = Number(payload.amount);
  const note = payload.note ? String(payload.note).trim() : null;

  if (!amount || amount <= 0 || amount % 500 !== 0) {
    throw new AppError(
      "L'approvisionnement doit etre un multiple positif de 500.",
      422,
    );
  }

  const result = await sequelize.transaction(async (transaction) =>
    applyAgentBalanceChange(
      agentProfile.id,
      {
        amount,
        isCredit: true,
        type: 'topUp',
        label: 'Approvisionnement de caisse',
        note,
        initiatedByUserId: agentProfile.userId,
        initiatorType: 'agent',
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        auditAction: 'agent.cash_topped_up',
        reference: generateCashReference('TOP'),
      },
      transaction,
    ),
  );

  return {
    reference: result.history.reference,
    amount,
    agentBalance: result.balanceAfter,
    occurredAt: result.history.occurredAt,
  };
}

module.exports = {
  applyAgentBalanceChange,
  getCashOverview,
  topUpCash,
  generateCashReference,
};
