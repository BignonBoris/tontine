const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { TONTINE_HISTORY_TYPES } = require('../../common/constants/enums');

const TontineHistory = sequelize.define(
  'TontineHistory',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    syncId: {
      type: DataTypes.UUID,
      allowNull: true,
      unique: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    cycleId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    type: {
      type: DataTypes.ENUM(...TONTINE_HISTORY_TYPES),
      allowNull: false,
    },
    paymentSource: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    linkedProvisioningId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    availableBalanceHistoryId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    reversalOfHistoryId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0,
      },
    },
    label: {
      type: DataTypes.STRING(160),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    note: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    initiatedByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    initiatorType: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    occurredAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'tontine_histories',
    indexes: [
      { fields: ['user_id', 'occurred_at'] },
      { fields: ['cycle_id', 'occurred_at'] },
      { fields: ['user_id', 'type'] },
      { fields: ['initiated_by_user_id', 'occurred_at'] },
      { fields: ['linked_provisioning_id'] },
      { fields: ['available_balance_history_id'] },
      { fields: ['reversal_of_history_id'] },
    ],
  },
);

module.exports = TontineHistory;
