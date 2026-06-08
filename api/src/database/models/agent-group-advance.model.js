const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  AGENT_GROUP_ADVANCE_STATUSES,
} = require('../../common/constants/enums');

const AgentGroupAdvance = sequelize.define(
  'AgentGroupAdvance',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    groupId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    contributionId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
    },
    memberId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    beneficiaryMemberId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    agentProfileId: {
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
    recoveredAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    status: {
      type: DataTypes.ENUM(...AGENT_GROUP_ADVANCE_STATUSES),
      allowNull: false,
      defaultValue: 'outstanding',
    },
    advancedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    recoveredAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    lastRecoveredAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'agent_group_advances',
    indexes: [
      { unique: true, fields: ['contribution_id'] },
      { fields: ['group_id', 'status', 'advanced_at'] },
      { fields: ['member_id', 'status', 'advanced_at'] },
      { fields: ['agent_profile_id', 'status', 'advanced_at'] },
    ],
  },
);

module.exports = AgentGroupAdvance;
