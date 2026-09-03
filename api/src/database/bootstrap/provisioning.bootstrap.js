const { DataTypes } = require('sequelize');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureProvisioningCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'provisionings');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('provisionings');

  if (!columns.sync_id) {
    try {
      await queryInterface.addColumn('provisionings', 'sync_id', {
        type: DataTypes.UUID,
        allowNull: true,
        unique: true,
      });
    } catch (err) {
      console.warn('⚠️ Remarque ajout colonne sync_id sur provisionings :', err.message);
    }
  }
}

module.exports = { ensureProvisioningCompatibility };
