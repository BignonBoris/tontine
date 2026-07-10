const { DataTypes } = require('sequelize');
const {
  TONTINE_PAYMENT_INTENT_STATUSES,
} = require('../../common/constants/enums');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureTontinePaymentIntentCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'tontine_payment_intents');

  if (!exists) {
    await queryInterface.createTable('tontine_payment_intents', {
      id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
      user_id: { type: DataTypes.UUID, allowNull: false },
      cycle_id: { type: DataTypes.UUID, allowNull: false },
      amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
      provider: {
        type: DataTypes.STRING(32),
        allowNull: false,
        defaultValue: 'fedapay',
      },
      merchant_reference: {
        type: DataTypes.STRING(80),
        allowNull: false,
        unique: true,
      },
      provider_transaction_id: {
        type: DataTypes.STRING(80),
        allowNull: true,
      },
      payment_url: {
        type: DataTypes.STRING(512),
        allowNull: true,
      },
      callback_url: {
        type: DataTypes.STRING(512),
        allowNull: true,
      },
      status: {
        type: DataTypes.ENUM(...TONTINE_PAYMENT_INTENT_STATUSES),
        allowNull: false,
        defaultValue: 'pending',
      },
      provider_status: {
        type: DataTypes.STRING(32),
        allowNull: true,
      },
      provider_payload: {
        type: DataTypes.JSON,
        allowNull: true,
      },
      failure_reason: {
        type: DataTypes.STRING(255),
        allowNull: true,
      },
      deposit_history_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      initiated_by_user_id: {
        type: DataTypes.UUID,
        allowNull: true,
      },
      initiator_type: {
        type: DataTypes.STRING(32),
        allowNull: true,
      },
      approved_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      processed_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      failed_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      cancelled_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      expired_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      updated_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    });
    return;
  }

  const columns = await queryInterface.describeTable('tontine_payment_intents');

  const ensureColumn = async (columnName, ddl) => {
    if (columns[columnName]) {
      return;
    }
    await sequelize.query(`ALTER TABLE tontine_payment_intents ADD ${ddl};`);
  };

  await ensureColumn('provider', "`provider` VARCHAR(32) NOT NULL DEFAULT 'fedapay'");
  await ensureColumn('merchant_reference', '`merchant_reference` VARCHAR(80) NOT NULL');
  await ensureColumn(
    'provider_transaction_id',
    '`provider_transaction_id` VARCHAR(80) NULL',
  );
  await ensureColumn('payment_url', '`payment_url` VARCHAR(512) NULL');
  await ensureColumn('callback_url', '`callback_url` VARCHAR(512) NULL');
  if (!columns.status) {
    await sequelize.query(
      `ALTER TABLE tontine_payment_intents ADD \`status\` ENUM(${TONTINE_PAYMENT_INTENT_STATUSES.map((value) => `'${value}'`).join(', ')}) NOT NULL DEFAULT 'pending';`,
    );
  } else {
    await sequelize.query(
      `ALTER TABLE tontine_payment_intents MODIFY \`status\` ENUM(${TONTINE_PAYMENT_INTENT_STATUSES.map((value) => `'${value}'`).join(', ')}) NOT NULL DEFAULT 'pending';`,
    );
  }
  await ensureColumn('provider_status', '`provider_status` VARCHAR(32) NULL');
  await ensureColumn('provider_payload', '`provider_payload` JSON NULL');
  await ensureColumn('failure_reason', '`failure_reason` VARCHAR(255) NULL');
  await ensureColumn('deposit_history_id', '`deposit_history_id` CHAR(36) BINARY NULL');
  await ensureColumn('initiated_by_user_id', '`initiated_by_user_id` CHAR(36) BINARY NULL');
  await ensureColumn('initiator_type', '`initiator_type` VARCHAR(32) NULL');
  await ensureColumn('approved_at', '`approved_at` DATETIME NULL');
  await ensureColumn('processed_at', '`processed_at` DATETIME NULL');
  await ensureColumn('failed_at', '`failed_at` DATETIME NULL');
  await ensureColumn('cancelled_at', '`cancelled_at` DATETIME NULL');
  await ensureColumn('expired_at', '`expired_at` DATETIME NULL');
}

module.exports = { ensureTontinePaymentIntentCompatibility };
