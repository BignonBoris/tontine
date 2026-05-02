const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { TONTINE_CYCLE_STATUSES } = require('../../common/constants/enums');

const TontineCycle = sequelize.define(
  'TontineCycle',
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
    stakeAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    cumulativeAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    status: {
      type: DataTypes.ENUM(...TONTINE_CYCLE_STATUSES),
      allowNull: false,
      defaultValue: 'nonConfiguree',
    },
    startedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    expectedEndAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    endedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'tontine_cycles',
    indexes: [
      { fields: ['user_id', 'status'] },
      { fields: ['user_id', 'created_at'] },
      { fields: ['started_at'] },
    ],
  },
);

module.exports = TontineCycle;
