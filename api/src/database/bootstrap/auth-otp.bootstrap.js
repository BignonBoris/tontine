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

  await sequelize.query(`ALTER TABLE auth_otps ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureAuthOtpCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'auth_otps');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('auth_otps');

  await ensureColumn(
    sequelize,
    columns,
    'attempt_count',
    '`attempt_count` INT NOT NULL DEFAULT 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'resend_count',
    '`resend_count` INT NOT NULL DEFAULT 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'last_sent_at',
    '`last_sent_at` DATETIME NULL',
    'UPDATE auth_otps SET last_sent_at = COALESCE(created_at, NOW()) WHERE last_sent_at IS NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'blocked_until',
    '`blocked_until` DATETIME NULL',
  );

  await sequelize.query(
    'UPDATE auth_otps SET attempt_count = 0 WHERE attempt_count IS NULL',
  );
  await sequelize.query(
    'UPDATE auth_otps SET resend_count = 0 WHERE resend_count IS NULL',
  );
  await sequelize.query(
    'UPDATE auth_otps SET last_sent_at = COALESCE(created_at, NOW()) WHERE last_sent_at IS NULL',
  );
}

module.exports = { ensureAuthOtpCompatibility };
