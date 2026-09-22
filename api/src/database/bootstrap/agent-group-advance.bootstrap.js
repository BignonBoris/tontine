async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function columnExists(sequelize, tableName, columnName) {
  const [rows] = await sequelize.query(
    `SELECT COUNT(*) as count FROM information_schema.COLUMNS 
     WHERE TABLE_SCHEMA = DATABASE() 
     AND TABLE_NAME = :tableName 
     AND COLUMN_NAME = :columnName`,
    { replacements: { tableName, columnName }, type: sequelize.QueryTypes.SELECT }
  );
  return rows.count > 0;
}

async function ensureAgentGroupAdvanceCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'agent_group_advances');
  if (!exists) {
    await sequelize.query(`
      CREATE TABLE agent_group_advances (
        id CHAR(36) NOT NULL PRIMARY KEY,
        group_id CHAR(36) NOT NULL,
        contribution_id CHAR(36) NOT NULL,
        member_id CHAR(36) NOT NULL,
        beneficiary_member_id CHAR(36) NOT NULL,
        agent_profile_id CHAR(36) NOT NULL,
        amount DECIMAL(18,2) NOT NULL,
        penalty_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
        penalty_paid TINYINT(1) NOT NULL DEFAULT 0,
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
    return;
  }

  // Migration des colonnes manquantes si la table existe déjà
  if (!(await columnExists(sequelize, 'agent_group_advances', 'penalty_amount'))) {
    await sequelize.query(
      `ALTER TABLE agent_group_advances 
       ADD COLUMN penalty_amount DECIMAL(18,2) NOT NULL DEFAULT 0 AFTER amount;`
    );
    console.log('[Bootstrap] Colonne penalty_amount ajoutée à agent_group_advances.');
  }

  if (!(await columnExists(sequelize, 'agent_group_advances', 'penalty_paid'))) {
    await sequelize.query(
      `ALTER TABLE agent_group_advances 
       ADD COLUMN penalty_paid TINYINT(1) NOT NULL DEFAULT 0 AFTER penalty_amount;`
    );
    console.log('[Bootstrap] Colonne penalty_paid ajoutée à agent_group_advances.');
  }
}

module.exports = { ensureAgentGroupAdvanceCompatibility };

