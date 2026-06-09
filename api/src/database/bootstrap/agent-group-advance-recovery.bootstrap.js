async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureAgentGroupAdvanceRecoveryCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_group_advance_recoveries');
  if (exists) {
    return;
  }

  await sequelize.query(`
    CREATE TABLE agent_group_advance_recoveries (
      id CHAR(36) NOT NULL PRIMARY KEY,
      advance_id CHAR(36) NOT NULL,
      group_id CHAR(36) NOT NULL,
      contribution_id CHAR(36) NOT NULL,
      member_id CHAR(36) NOT NULL,
      beneficiary_member_id CHAR(36) NOT NULL,
      agent_profile_id CHAR(36) NOT NULL,
      reference VARCHAR(64) NOT NULL,
      amount DECIMAL(18,2) NOT NULL,
      recovered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_agent_group_advance_recoveries_reference (reference),
      KEY idx_agent_group_advance_recoveries_advance_recovered (advance_id, recovered_at),
      KEY idx_agent_group_advance_recoveries_group_member_recovered (group_id, member_id, recovered_at),
      KEY idx_agent_group_advance_recoveries_agent_recovered (agent_profile_id, recovered_at)
    );
  `);
}

module.exports = { ensureAgentGroupAdvanceRecoveryCompatibility };
