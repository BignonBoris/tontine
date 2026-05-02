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
    ],
  },
);

module.exports = TontineHistory;
