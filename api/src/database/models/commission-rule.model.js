const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const CommissionRule = sequelize.define(
  'CommissionRule',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    code: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },
    name: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('active', 'inactive'),
      allowNull: false,
      defaultValue: 'active',
    },
    calculationMode: {
      type: DataTypes.ENUM('fixed', 'percentage'),
      allowNull: false,
      defaultValue: 'fixed',
    },
    fixedCycleCommissionAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
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
    createdByAdminId: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    updatedByAdminId: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    effectiveFrom: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    effectiveTo: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'commission_rules',
    indexes: [
      { unique: true, fields: ['code'] },
      { fields: ['status', 'effective_from'] },
    ],
  },
);

module.exports = CommissionRule;
