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

  await sequelize.query(`ALTER TABLE users ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureUserCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'users');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('users');

  await ensureColumn(
    sequelize,
    columns,
    'created_by_agent_profile_id',
    '`created_by_agent_profile_id` CHAR(36) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'first_name',
    '`first_name` VARCHAR(80) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'last_name',
    '`last_name` VARCHAR(80) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'birth_date',
    '`birth_date` DATE NULL',
  );

  if (columns.phone_number && columns.phone_number.allowNull === false) {
    await sequelize.query(
      'ALTER TABLE `users` MODIFY `phone_number` VARCHAR(32) NULL;',
    );
  }

  await ensureColumn(
    sequelize,
    columns,
    'punctuality_score',
    '`punctuality_score` INT NOT NULL DEFAULT 50'
  );

  await sequelize.query(
    "UPDATE `users` SET `phone_number` = NULL WHERE TRIM(COALESCE(`phone_number`, '')) = '';",
  );
}

module.exports = { ensureUserCompatibility };
