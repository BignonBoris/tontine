const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const {
  PAYMENT_METHOD_OPERATIONS,
  PAYMENT_METHOD_FLOW_TYPES,
} = require('./payment-methods.constants');

function normalizePaymentMethodCode(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizePaymentMethodOperation(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) {
    return null;
  }
  if (!PAYMENT_METHOD_OPERATIONS.includes(normalized)) {
    throw new AppError('Operation de paiement invalide.', 422);
  }
  return normalized;
}

function normalizePaymentMethodFlowType(value) {
  const normalized = String(value || '').trim().toLowerCase();
  if (!normalized) {
    return null;
  }
  if (!PAYMENT_METHOD_FLOW_TYPES.includes(normalized)) {
    throw new AppError('Type de flux de paiement invalide.', 422);
  }
  return normalized;
}

function serializePaymentMethod(method) {
  if (!method) {
    return null;
  }

  return {
    id: method.id,
    code: method.code,
    label: method.label,
    description: method.description || null,
    provider: method.provider,
    operation: method.operation,
    flowType: method.flowType,
    enabled: Boolean(method.enabled),
    sortOrder: Number(method.sortOrder || 0),
    metadata: method.metadata || null,
    createdAt: method.createdAt,
    updatedAt: method.updatedAt,
  };
}

async function listPaymentMethods(options = {}) {
  const operation = normalizePaymentMethodOperation(options.operation);
  const includeDisabled = Boolean(options.includeDisabled);

  const whereClause = {};
  if (operation) {
    whereClause.operation = operation;
  }
  if (!includeDisabled) {
    whereClause.enabled = true;
  }

  const methods = await models.PaymentMethod.findAll({
    where: whereClause,
    order: [
      ['sortOrder', 'ASC'],
      ['label', 'ASC'],
    ],
  });

  const items = methods.map(serializePaymentMethod);

  return {
    items,
    totals: {
      total: items.length,
      enabled: items.filter((method) => method.enabled).length,
      disabled: items.filter((method) => !method.enabled).length,
    },
    operation,
  };
}

async function getPaymentMethodByCode(code, options = {}) {
  const normalizedCode = normalizePaymentMethodCode(code);
  if (!normalizedCode) {
    return null;
  }

  const operation = normalizePaymentMethodOperation(options.operation);
  const includeDisabled = Boolean(options.includeDisabled);

  const whereClause = { code: normalizedCode };
  if (operation) {
    whereClause.operation = operation;
  }
  if (!includeDisabled) {
    whereClause.enabled = true;
  }

  return models.PaymentMethod.findOne({ where: whereClause });
}

async function assertPaymentMethodEnabled(code, operation, message) {
  const method = await getPaymentMethodByCode(code, {
    operation,
    includeDisabled: true,
  });

  if (!method) {
    throw new AppError('Moyen de paiement introuvable.', 404);
  }

  if (operation && method.operation !== operation) {
    throw new AppError('Moyen de paiement invalide pour cette operation.', 422);
  }

  if (!method.enabled) {
    throw new AppError(
      message || 'Ce moyen de paiement est temporairement indisponible.',
      422,
    );
  }

  return method;
}

async function togglePaymentMethod(methodId, payload = {}, requestContext = {}) {
  if (typeof payload?.enabled !== 'boolean') {
    throw new AppError('Le statut du moyen de paiement est requis.', 422);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const method = await models.PaymentMethod.findByPk(methodId, {
      transaction,
      lock: transaction.LOCK.UPDATE,
    });

    if (!method) {
      throw new AppError('Moyen de paiement introuvable.', 404);
    }

    await method.update(
      {
        enabled: payload.enabled,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: null,
      action: payload.enabled
        ? 'payment_method.enabled'
        : 'payment_method.disabled',
      entityType: 'payment_method',
      entityId: method.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        adminUsername: requestContext.adminUsername || null,
        code: method.code,
        label: method.label,
        operation: method.operation,
        flowType: method.flowType,
        enabled: payload.enabled,
      },
      transaction,
    });

    return method;
  });

  return serializePaymentMethod(result);
}

module.exports = {
  listPaymentMethods,
  getPaymentMethodByCode,
  assertPaymentMethodEnabled,
  togglePaymentMethod,
  serializePaymentMethod,
  normalizePaymentMethodOperation,
  normalizePaymentMethodCode,
};
