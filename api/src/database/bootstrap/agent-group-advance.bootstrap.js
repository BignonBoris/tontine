async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureAgentGroupAdvanceCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_group_advances');
  if (exists) {
    return;
  }

  await sequelize.query(`
    CREATE TABLE agent_group_advances (
      id CHAR(36) NOT NULL PRIMARY KEY,
      group_id CHAR(36) NOT NULL,
      contribution_id CHAR(36) NOT NULL,
      member_id CHAR(36) NOT NULL,
      beneficiary_member_id CHAR(36) NOT NULL,
      agent_profile_id CHAR(36) NOT NULL,
      amount DECIMAL(18,2) NOT NULL,
      recovered_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
      status ENUM('outstanding', 'partially_recovered', 'recovered', 'escalated') NOT NULL DEFAULT 'outstanding',
      advanced_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      recovered_at DATETIME NULL,
      last_recovered_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_agent_group_advances_contribution (contribution_id),
      KEY idx_agent_group_advances_group_status_advanced (group_id, status, advanced_at),
      KEY idx_agent_group_advances_member_status_advanced (member_id, status, advanced_at),
      KEY idx_agent_group_advances_agent_status_advanced (agent_profile_id, status, advanced_at)
    );
  `);
}

module.exports = { ensureAgentGroupAdvanceCompatibility };
