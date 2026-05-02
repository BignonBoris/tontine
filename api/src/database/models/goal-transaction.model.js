const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const GoalTransaction = sequelize.define(
  'GoalTransaction',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    goalId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    title: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    isDeposit: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
    },
    occurredAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  { tableName: 'goal_transactions' },
);

module.exports = GoalTransaction;
