const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const WithdrawalCommissionReserve = sequelize.define(
  'WithdrawalCommissionReserve',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    clientId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    cycleId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    snapshotId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    stakeAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    sourceAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    remainingSourceAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    consumedSourceAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    initialReservedAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    availableAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    consumedAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    sequence: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('open', 'consumed', 'closed'),
      allowNull: false,
      defaultValue: 'open',
    },
  },
  {
    tableName: 'withdrawal_commission_reserves',
    indexes: [
      { fields: ['client_id', 'sequence'] },
      { fields: ['client_id', 'status'] },
      { unique: true, fields: ['cycle_id'] },
    ],
  },
);

module.exports = WithdrawalCommissionReserve;
