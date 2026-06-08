async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureUserPreferenceCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'user_preferences');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('user_preferences');
  const pinCodeColumn = columns.pin_code || columns.pinCode;

  if (!pinCodeColumn) {
    await sequelize.query(
      'ALTER TABLE user_preferences ADD `pin_code` VARCHAR(128) NULL;',
    );
    return;
  }

  const type = String(pinCodeColumn.type || '').toUpperCase();
  if (!type.includes('VARCHAR(128)')) {
    await sequelize.query(
      'ALTER TABLE user_preferences MODIFY `pin_code` VARCHAR(128) NULL;',
    );
  }
}

module.exports = { ensureUserPreferenceCompatibility };
