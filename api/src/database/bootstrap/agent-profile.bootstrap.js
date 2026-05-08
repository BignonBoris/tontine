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

  await sequelize.query(`ALTER TABLE agent_profiles ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureAgentProfileCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_profiles');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('agent_profiles');

  await ensureColumn(
    sequelize,
    columns,
    'agent_balance',
    '`agent_balance` DECIMAL(18,2) NOT NULL DEFAULT 0',
    'UPDATE agent_profiles SET agent_balance = 0 WHERE agent_balance IS NULL',
  );

  await sequelize.query(
    'UPDATE agent_profiles SET agent_balance = 0 WHERE agent_balance IS NULL',
  );
}

module.exports = { ensureAgentProfileCompatibility };
