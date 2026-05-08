const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

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
    },
    status: {
      type: DataTypes.ENUM('requested', 'paid', 'cancelled', 'rejected'),
      allowNull: false,
      defaultValue: 'requested',
    },
    channel: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'cash',
    },
    requestedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    paidAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    cancelledAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    rejectedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    paidByAgentProfileId: {
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
    notes: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
  },
  {
    tableName: 'withdrawals',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['user_id', 'created_at'] },
      { fields: ['status', 'created_at'] },
      { fields: ['paid_by_agent_profile_id', 'created_at'] },
    ],
  },
);

module.exports = Withdrawal;
