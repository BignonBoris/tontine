const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  AGENT_BALANCE_HISTORY_TYPES,
} = require('../../common/constants/enums');

const AgentBalanceHistory = sequelize.define(
  'AgentBalanceHistory',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    agentProfileId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    type: {
      type: DataTypes.ENUM(...AGENT_BALANCE_HISTORY_TYPES),
      allowNull: false,
    },
    reference: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    isCredit: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
    },
    balanceBefore: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    balanceAfter: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    label: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    note: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    relatedEntityType: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    relatedEntityId: {
      type: DataTypes.STRING(128),
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
    tableName: 'agent_balance_histories',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['agent_profile_id', 'occurred_at'] },
      { fields: ['agent_profile_id', 'type'] },
    ],
  },
);

module.exports = AgentBalanceHistory;
