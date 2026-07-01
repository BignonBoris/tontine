const { DataTypes } = require('sequelize');
const { AVAILABLE_BALANCE_HISTORY_TYPES } = require('../../common/constants/enums');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureAvailableBalanceHistoryCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'available_balance_histories');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('available_balance_histories');
  if (!columns.type) {
    await sequelize.query(
      `ALTER TABLE available_balance_histories ADD \`type\` ENUM(${AVAILABLE_BALANCE_HISTORY_TYPES.map((value) => `'${value}'`).join(', ')}) NOT NULL;`,
    );
  } else {
    await sequelize.query(
      `ALTER TABLE available_balance_histories MODIFY \`type\` ENUM(${AVAILABLE_BALANCE_HISTORY_TYPES.map((value) => `'${value}'`).join(', ')}) NOT NULL;`,
    );
  }

  if (!columns.reversal_of_history_id) {
    await queryInterface.addColumn('available_balance_histories', 'reversal_of_history_id', {
      type: DataTypes.UUID,
      allowNull: true,
    });
  }
}

module.exports = { ensureAvailableBalanceHistoryCompatibility };
