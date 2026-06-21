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

  await sequelize.query(`ALTER TABLE agent_groups ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureAgentGroupCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_groups');
  if (!exists) {
    await sequelize.query(`
      CREATE TABLE agent_groups (
        id CHAR(36) NOT NULL PRIMARY KEY,
        reference VARCHAR(64) NOT NULL,
        agent_profile_id CHAR(36) NOT NULL,
        name VARCHAR(160) NOT NULL,
        normalized_name VARCHAR(160) NOT NULL,
        description VARCHAR(255) NULL,
        participant_count INT NOT NULL,
        member_count INT NOT NULL DEFAULT 0,
        turn_interval_value INT NOT NULL,
        turn_interval_unit ENUM('day', 'week', 'month') NOT NULL,
        contribution_amount DECIMAL(18,2) NOT NULL,
        commission_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
        planned_start_date DATETIME NOT NULL,
        launch_status ENUM('collecting', 'ready', 'started', 'launch_cancelled') NOT NULL DEFAULT 'collecting',
        started_at DATETIME NULL,
        launch_cancelled_at DATETIME NULL,
        launch_cancellation_reason VARCHAR(255) NULL,
        status ENUM('active', 'suspended') NOT NULL DEFAULT 'active',
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_agent_groups_reference (reference),
        UNIQUE KEY uq_agent_groups_agent_name (agent_profile_id, normalized_name),
        KEY idx_agent_groups_agent_status_created (agent_profile_id, status, created_at),
        KEY idx_agent_groups_agent_turn_unit_created (agent_profile_id, turn_interval_unit, created_at),
        KEY idx_agent_groups_launch_status_planned_start (launch_status, planned_start_date),
        KEY idx_agent_groups_status_created (status, created_at)
      );
    `);
    return;
  }

  const columns = await queryInterface.describeTable('agent_groups');
  await ensureColumn(
    sequelize,
    columns,
    'participant_count',
    '`participant_count` INT NOT NULL DEFAULT 2',
    'UPDATE agent_groups SET participant_count = 2 WHERE participant_count IS NULL OR participant_count < 2',
  );
  await ensureColumn(
    sequelize,
    columns,
    'member_count',
    '`member_count` INT NOT NULL DEFAULT 0',
    'UPDATE agent_groups SET member_count = 0 WHERE member_count IS NULL OR member_count < 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'turn_interval_value',
    '`turn_interval_value` INT NOT NULL DEFAULT 1',
    'UPDATE agent_groups SET turn_interval_value = 1 WHERE turn_interval_value IS NULL OR turn_interval_value < 1',
  );
  await ensureColumn(
    sequelize,
    columns,
    'turn_interval_unit',
    "`turn_interval_unit` ENUM('day', 'week', 'month') NOT NULL DEFAULT 'month'",
    "UPDATE agent_groups SET turn_interval_unit = 'month' WHERE turn_interval_unit IS NULL OR turn_interval_unit = ''",
  );
  await ensureColumn(
    sequelize,
    columns,
    'contribution_amount',
    '`contribution_amount` DECIMAL(18,2) NOT NULL DEFAULT 100',
    'UPDATE agent_groups SET contribution_amount = 100 WHERE contribution_amount IS NULL OR contribution_amount <= 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'commission_amount',
    '`commission_amount` DECIMAL(18,2) NOT NULL DEFAULT 0',
    'UPDATE agent_groups SET commission_amount = 0 WHERE commission_amount IS NULL OR commission_amount < 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'planned_start_date',
    '`planned_start_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP',
    'UPDATE agent_groups SET planned_start_date = COALESCE(planned_start_date, created_at, NOW()) WHERE planned_start_date IS NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'launch_status',
    "`launch_status` ENUM('collecting', 'ready', 'started', 'launch_cancelled') NOT NULL DEFAULT 'collecting'",
    "UPDATE agent_groups SET launch_status = 'collecting' WHERE launch_status IS NULL OR launch_status = ''",
  );
  await ensureColumn(
    sequelize,
    columns,
    'started_at',
    '`started_at` DATETIME NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'launch_cancelled_at',
    '`launch_cancelled_at` DATETIME NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'launch_cancellation_reason',
    '`launch_cancellation_reason` VARCHAR(255) NULL',
  );
}

module.exports = { ensureAgentGroupCompatibility };
