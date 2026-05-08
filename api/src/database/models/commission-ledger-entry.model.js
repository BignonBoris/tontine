const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const CommissionLedgerEntry = sequelize.define(
  'CommissionLedgerEntry',
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
    entryType: {
      type: DataTypes.STRING(64),
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('posted', 'reversed', 'blocked', 'settled'),
      allowNull: false,
      defaultValue: 'posted',
    },
    sourceType: {
      type: DataTypes.STRING(64),
      allowNull: false,
    },
    sourceId: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    cycleId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    clientId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    agentId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    walletId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    direction: {
      type: DataTypes.ENUM('credit', 'debit'),
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    payableAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    blockedAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    currency: {
      type: DataTypes.STRING(8),
      allowNull: false,
      defaultValue: 'XOF',
    },
    commissionBucket: {
      type: DataTypes.STRING(32),
      allowNull: false,
    },
    snapshotId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    triggerEvent: {
      type: DataTypes.STRING(64),
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
    reversalOfEntryId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: {},
    },
  },
  {
    tableName: 'commission_ledger_entries',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['cycle_id', 'created_at'] },
      { fields: ['client_id', 'created_at'] },
      { fields: ['agent_id', 'created_at'] },
      { fields: ['wallet_id', 'created_at'] },
      { fields: ['entry_type'] },
      { fields: ['commission_bucket'] },
      { fields: ['status'] },
    ],
  },
);

module.exports = CommissionLedgerEntry;
