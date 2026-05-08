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

  await sequelize.query(
    "UPDATE withdrawals SET confirmation_code_hash = 'legacy-withdrawal-code' WHERE confirmation_code_hash IS NULL OR confirmation_code_hash = ''",
  );
  await sequelize.query(
    'UPDATE withdrawals SET confirmation_code_expires_at = COALESCE(requested_at, created_at, NOW()) WHERE confirmation_code_expires_at IS NULL',
  );
  await sequelize.query(
    'UPDATE withdrawals SET confirmation_code_attempts = 0 WHERE confirmation_code_attempts IS NULL',
  );
}

module.exports = { ensureWithdrawalCompatibility };
