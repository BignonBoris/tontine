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
}

module.exports = { ensureUserCompatibility };
