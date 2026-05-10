const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const CycleCommissionSnapshot = sequelize.define(
  'CycleCommissionSnapshot',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    tontineCycleId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
    },
    commissionRuleId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    stakeAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    cycleCommissionAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    platformShareRate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    depositAgentShareRate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    withdrawalAgentShareRate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    bonusShareRate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    floatingEnabled: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    snapshotPayload: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: {},
    },
  },
  {
    tableName: 'cycle_commission_snapshots',
    indexes: [
      { unique: true, fields: ['tontine_cycle_id'] },
      { fields: ['user_id', 'created_at'] },
      { fields: ['commission_rule_id'] },
    ],
  },
);

module.exports = CycleCommissionSnapshot;
