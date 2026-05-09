const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const WithdrawalCommissionConsumption = sequelize.define(
  'WithdrawalCommissionConsumption',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    reference: {
      type: DataTypes.STRING(80),
      allowNull: false,
      unique: true,
    },
    withdrawalId: {
      type: DataTypes.STRING(64),
      allowNull: false,
    },
    clientId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    reserveId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    cycleId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    agentId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    consumedAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    agentCommissionAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    platformCommissionAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
  },
  {
    tableName: 'withdrawal_commission_consumptions',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['withdrawal_id'] },
      { fields: ['client_id', 'created_at'] },
      { fields: ['reserve_id', 'created_at'] },
      { fields: ['cycle_id', 'created_at'] },
    ],
  },
);

module.exports = WithdrawalCommissionConsumption;
