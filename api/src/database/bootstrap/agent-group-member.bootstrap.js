async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureAgentGroupMemberCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_group_members');
  if (exists) {
    await sequelize.query(`
      ALTER TABLE agent_group_members
      MODIFY COLUMN status ENUM('requested', 'invited', 'active', 'declined', 'rejected', 'removed') NOT NULL DEFAULT 'invited';
    `);
    const columns = await queryInterface.describeTable('agent_group_members');
    if (!columns.turn_position) {
      await sequelize.query(`
        ALTER TABLE agent_group_members
        ADD COLUMN turn_position INT NULL AFTER joined_at;
      `);
      await sequelize.query(`
        CREATE INDEX idx_agent_group_members_group_turn_position
        ON agent_group_members (group_id, turn_position);
      `);
    }
    return;
  }

  await sequelize.query(`
    CREATE TABLE agent_group_members (
      id CHAR(36) NOT NULL PRIMARY KEY,
      group_id CHAR(36) NOT NULL,
      client_user_id CHAR(36) NOT NULL,
      status ENUM('requested', 'invited', 'active', 'declined', 'rejected', 'removed') NOT NULL DEFAULT 'invited',
      joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      turn_position INT NULL,
      removed_at DATETIME NULL,
      removal_reason VARCHAR(255) NULL,
      added_by_user_id CHAR(36) NULL,
      removed_by_user_id CHAR(36) NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uq_agent_group_members_group_client (group_id, client_user_id),
      KEY idx_agent_group_members_group_turn_position (group_id, turn_position),
      KEY idx_agent_group_members_group_status_created (group_id, status, created_at),
      KEY idx_agent_group_members_client_status_created (client_user_id, status, created_at)
    );
  `);
}

module.exports = { ensureAgentGroupMemberCompatibility };
