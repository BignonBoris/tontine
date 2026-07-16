async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureColumn(sequelize, columns, columnName, ddl, backfillSql) {
  if (columns[columnName]) {
    return;
  }

  await sequelize.query(`ALTER TABLE withdrawals ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureWithdrawalCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'withdrawals');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('withdrawals');

  await sequelize.query(
    "ALTER TABLE withdrawals MODIFY COLUMN status VARCHAR(32) NOT NULL DEFAULT 'requested'",
  );
  await sequelize.query(
    "ALTER TABLE withdrawals MODIFY COLUMN channel VARCHAR(32) NOT NULL DEFAULT 'agent_cash'",
  );

  await ensureColumn(
    sequelize,
    columns,
    'channel',
    "`channel` VARCHAR(32) NOT NULL DEFAULT 'agent_cash'",
  );
  await ensureColumn(
    sequelize,
    columns,
    'confirmation_code_hash',
    "`confirmation_code_hash` VARCHAR(128) NOT NULL DEFAULT 'legacy-withdrawal-code'",
  );
  await ensureColumn(
    sequelize,
    columns,
    'confirmation_code_expires_at',
    '`confirmation_code_expires_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
  );
  await ensureColumn(
    sequelize,
    columns,
    'confirmation_code_attempts',
    '`confirmation_code_attempts` INT NOT NULL DEFAULT 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'approved_at',
    '`approved_at` DATETIME NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'approved_by_admin_username',
    '`approved_by_admin_username` VARCHAR(120) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'paid_by_admin_username',
    '`paid_by_admin_username` VARCHAR(120) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'payment_reference',
    '`payment_reference` VARCHAR(120) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'payment_proof_image_url',
    '`payment_proof_image_url` VARCHAR(255) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'payment_proof_uploaded_at',
    '`payment_proof_uploaded_at` DATETIME NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'rejection_reason',
    '`rejection_reason` VARCHAR(255) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'rejected_at',
    '`rejected_at` DATETIME NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'cancellation_reason',
    '`cancellation_reason` VARCHAR(255) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'paid_by_agent_profile_id',
    '`paid_by_agent_profile_id` CHAR(36) BINARY NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'initiated_by_user_id',
    '`initiated_by_user_id` CHAR(36) BINARY NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'initiator_type',
    '`initiator_type` VARCHAR(32) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'notes',
    '`notes` VARCHAR(255) NULL',
  );

  await sequelize.query(
    "UPDATE withdrawals SET confirmation_code_hash = 'legacy-withdrawal-code' WHERE confirmation_code_hash IS NULL OR confirmation_code_hash = ''",
  );
  await sequelize.query(
    'UPDATE withdrawals SET confirmation_code_expires_at = COALESCE(requested_at, created_at, NOW()) WHERE confirmation_code_expires_at IS NULL',
  );
  await sequelize.query(
    'UPDATE withdrawals SET confirmation_code_attempts = 0 WHERE confirmation_code_attempts IS NULL',
  );
  await sequelize.query(
    "UPDATE withdrawals SET channel = 'agent_cash' WHERE channel IS NULL OR channel = ''",
  );
}

module.exports = { ensureWithdrawalCompatibility };
