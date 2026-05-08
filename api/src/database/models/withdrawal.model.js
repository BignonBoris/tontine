const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  WITHDRAWAL_STATUSES,
  WITHDRAWAL_CHANNELS,
} = require('../../common/constants/enums');

const Withdrawal = sequelize.define(
  'Withdrawal',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    reference: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    status: {
      type: DataTypes.ENUM(...WITHDRAWAL_STATUSES),
      allowNull: false,
      defaultValue: 'requested',
    },
    channel: {
      type: DataTypes.ENUM(...WITHDRAWAL_CHANNELS),
      allowNull: false,
      defaultValue: 'agent_cash',
    },
    requestedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    confirmationCodeHash: {
      type: DataTypes.STRING(128),
      allowNull: false,
    },
    confirmationCodeExpiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    confirmationCodeAttempts: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    paidAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    cancelledAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    paidByUserId: {
      type: DataTypes.UUID,
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
    cancellationReason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
  },
  {
    tableName: 'withdrawals',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['user_id', 'status', 'created_at'] },
      { fields: ['reference', 'status'] },
      { fields: ['paid_by_user_id', 'created_at'] },
    ],
  },
);

module.exports = Withdrawal;
