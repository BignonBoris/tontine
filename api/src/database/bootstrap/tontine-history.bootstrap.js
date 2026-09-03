const { DataTypes } = require('sequelize');
const {
  TONTINE_HISTORY_TYPES,
} = require('../../common/constants/enums');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureTontineHistoryCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'tontine_histories');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('tontine_histories');

  if (!columns.type) {
    await sequelize.query(
      `ALTER TABLE tontine_histories ADD \`type\` ENUM(${TONTINE_HISTORY_TYPES.map((value) => `'${value}'`).join(', ')}) NOT NULL;`,
    );
  } else {
    await sequelize.query(
      `ALTER TABLE tontine_histories MODIFY \`type\` ENUM(${TONTINE_HISTORY_TYPES.map((value) => `'${value}'`).join(', ')}) NOT NULL;`,
    );
  }

  if (!columns.sync_id) {
    try {
      await queryInterface.addColumn('tontine_histories', 'sync_id', {
        type: DataTypes.UUID,
        allowNull: true,
        unique: true,
      });
    } catch (err) {
      console.warn('⚠️ Remarque ajout colonne sync_id sur tontine_histories :', err.message);
    }
  }

  if (!columns.payment_source) {
    await queryInterface.addColumn('tontine_histories', 'payment_source', {
      type: DataTypes.STRING(32),
      allowNull: true,
    });
  }

  if (!columns.linked_provisioning_id) {
    await queryInterface.addColumn('tontine_histories', 'linked_provisioning_id', {
      type: DataTypes.UUID,
      allowNull: true,
    });
  }

  if (!columns.available_balance_history_id) {
    await queryInterface.addColumn('tontine_histories', 'available_balance_history_id', {
      type: DataTypes.UUID,
      allowNull: true,
    });
  }

  if (!columns.reversal_of_history_id) {
    await queryInterface.addColumn('tontine_histories', 'reversal_of_history_id', {
      type: DataTypes.UUID,
      allowNull: true,
    });
  }

  if (!columns.initiated_by_user_id) {
    try {
      await queryInterface.addColumn('tontine_histories', 'initiated_by_user_id', {
        type: DataTypes.UUID,
        allowNull: true,
      });
    } catch (err) {
      console.warn('⚠️ Remarque ajout colonne initiated_by_user_id sur tontine_histories :', err.message);
    }
  }

  if (!columns.initiator_type) {
    try {
      await queryInterface.addColumn('tontine_histories', 'initiator_type', {
        type: DataTypes.STRING(32),
        allowNull: true,
      });
    } catch (err) {
      console.warn('⚠️ Remarque ajout colonne initiator_type sur tontine_histories :', err.message);
    }
  }
}

module.exports = { ensureTontineHistoryCompatibility };
