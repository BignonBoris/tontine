const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  AVAILABLE_BALANCE_HISTORY_TYPES,
} = require('../../common/constants/enums');

const AvailableBalanceHistory = sequelize.define(
  'AvailableBalanceHistory',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    type: {
      type: DataTypes.ENUM(...AVAILABLE_BALANCE_HISTORY_TYPES),
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    label: {
      type: DataTypes.STRING(160),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    isCredit: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
    },
    occurredAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'available_balance_histories',
    indexes: [
      { fields: ['user_id', 'occurred_at'] },
      { fields: ['user_id', 'type'] },
    ],
  },
);

module.exports = AvailableBalanceHistory;
