const { DataTypes } = require('sequelize');
const {
  DEFAULT_PAYMENT_METHODS,
  PAYMENT_METHOD_OPERATIONS,
  PAYMENT_METHOD_FLOW_TYPES,
} = require('../../modules/payment-methods/payment-methods.constants');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureColumn(sequelize, columns, columnName, ddl) {
  if (columns[columnName]) {
    return;
  }

  await sequelize.query(`ALTER TABLE payment_methods ADD ${ddl};`);
}

function normalizePaymentMethodSeed(seed) {
  return {
    code: String(seed.code || '').trim().toLowerCase(),
    label: String(seed.label || '').trim(),
    description: seed.description ? String(seed.description).trim() : null,
    provider: String(seed.provider || 'internal').trim().toLowerCase(),
    operation: String(seed.operation || '').trim().toLowerCase(),
    flowType: String(seed.flowType || 'internal_transfer').trim().toLowerCase(),
    enabled: Boolean(seed.enabled),
    sortOrder: Number(seed.sortOrder || 0),
    metadata: seed.metadata || null,
  };
}

async function ensurePaymentMethodSeed(models) {
  for (const seed of DEFAULT_PAYMENT_METHODS) {
    const normalizedSeed = normalizePaymentMethodSeed(seed);
    const [paymentMethod, created] = await models.PaymentMethod.findOrCreate({
      where: { code: normalizedSeed.code },
      defaults: normalizedSeed,
    });

    if (created) {
      continue;
    }

    const patch = {};
    if (!paymentMethod.label) patch.label = normalizedSeed.label;
    if (paymentMethod.description == null && normalizedSeed.description) {
      patch.description = normalizedSeed.description;
    }
    if (!paymentMethod.provider) patch.provider = normalizedSeed.provider;
    if (!paymentMethod.operation) patch.operation = normalizedSeed.operation;
    if (!paymentMethod.flowType) patch.flowType = normalizedSeed.flowType;
    if (paymentMethod.sortOrder == null) patch.sortOrder = normalizedSeed.sortOrder;
    if (paymentMethod.metadata == null && normalizedSeed.metadata) {
      patch.metadata = normalizedSeed.metadata;
    }

    if (Object.keys(patch).length > 0) {
      await paymentMethod.update(patch);
    }
  }
}

async function ensurePaymentMethodCompatibility(sequelize, models) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'payment_methods');

  if (!exists) {
    await queryInterface.createTable('payment_methods', {
      id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
      code: { type: DataTypes.STRING(64), allowNull: false, unique: true },
      label: { type: DataTypes.STRING(120), allowNull: false },
      description: { type: DataTypes.STRING(255), allowNull: true },
      provider: {
        type: DataTypes.STRING(64),
        allowNull: false,
        defaultValue: 'internal',
      },
      operation: { type: DataTypes.STRING(32), allowNull: false },
      flow_type: {
        type: DataTypes.STRING(32),
        allowNull: false,
        defaultValue: 'internal_transfer',
      },
      enabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
      sort_order: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
      metadata: { type: DataTypes.JSON, allowNull: true },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    });

    await ensurePaymentMethodSeed(models);
    return;
  }

  const columns = await queryInterface.describeTable('payment_methods');

  await ensureColumn(sequelize, columns, 'code', "`code` VARCHAR(64) NOT NULL");
  await ensureColumn(sequelize, columns, 'label', "`label` VARCHAR(120) NOT NULL");
  await ensureColumn(
    sequelize,
    columns,
    'description',
    '`description` VARCHAR(255) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'provider',
    "`provider` VARCHAR(64) NOT NULL DEFAULT 'internal'",
  );
  await ensureColumn(
    sequelize,
    columns,
    'operation',
    '`operation` VARCHAR(32) NOT NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'flow_type',
    "`flow_type` VARCHAR(32) NOT NULL DEFAULT 'internal_transfer'",
  );
  await ensureColumn(
    sequelize,
    columns,
    'enabled',
    '`enabled` TINYINT(1) NOT NULL DEFAULT 1',
  );
  await ensureColumn(
    sequelize,
    columns,
    'sort_order',
    '`sort_order` INT NOT NULL DEFAULT 0',
  );
  await ensureColumn(sequelize, columns, 'metadata', '`metadata` JSON NULL');

  await sequelize.query(
    "UPDATE payment_methods SET provider = 'internal' WHERE provider IS NULL OR provider = ''",
  );
  await sequelize.query(
    "UPDATE payment_methods SET flow_type = 'internal_transfer' WHERE flow_type IS NULL OR flow_type = ''",
  );
  await sequelize.query(
    "UPDATE payment_methods SET sort_order = 0 WHERE sort_order IS NULL",
  );
  await sequelize.query(
    "UPDATE payment_methods SET enabled = 1 WHERE enabled IS NULL",
  );

  const validOperationValues = PAYMENT_METHOD_OPERATIONS.map((value) => `'${value}'`).join(', ');
  await sequelize.query(
    `UPDATE payment_methods SET operation = 'tontine_deposit' WHERE operation NOT IN (${validOperationValues}) OR operation IS NULL OR operation = ''`,
  );

  const validFlowValues = PAYMENT_METHOD_FLOW_TYPES.map((value) => `'${value}'`).join(', ');
  await sequelize.query(
    `UPDATE payment_methods SET flow_type = 'internal_transfer' WHERE flow_type NOT IN (${validFlowValues}) OR flow_type IS NULL OR flow_type = ''`,
  );

  await ensurePaymentMethodSeed(models);
}

module.exports = { ensurePaymentMethodCompatibility };
