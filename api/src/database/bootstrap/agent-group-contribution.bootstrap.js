async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureAgentGroupContributionCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_group_contributions');
  if (exists) {
    return;
  }

  await sequelize.query(`
    CREATE TABLE agent_group_contributions (
      id CHAR(36) NOT NULL PRIMARY KEY,
      group_id CHAR(36) NOT NULL,
      member_id CHAR(36) NOT NULL,
      beneficiary_member_id CHAR(36) NOT NULL,
      turn_number INT NOT NULL,
      due_date DATETIME NOT NULL,
      amount DECIMAL(18,2) NOT NULL,
      status ENUM('pending', 'paid', 'cancelled') NOT NULL DEFAULT 'pending',
      payment_source VARCHAR(32) NULL,
      paid_at DATETIME NULL,
      paid_by_agent_profile_id CHAR(36) NULL,
      paid_by_user_id CHAR(36) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_agent_group_contributions_group_member_turn (group_id, member_id, turn_number),
      KEY idx_agent_group_contributions_group_turn_status (group_id, turn_number, status),
      KEY idx_agent_group_contributions_member_status_turn (member_id, status, turn_number),
      KEY idx_agent_group_contributions_beneficiary_turn (beneficiary_member_id, turn_number)
    );
  `);
}

module.exports = { ensureAgentGroupContributionCompatibility };
