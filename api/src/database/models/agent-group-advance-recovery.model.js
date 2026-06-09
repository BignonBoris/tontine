const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const AgentGroupAdvanceRecovery = sequelize.define(
  'AgentGroupAdvanceRecovery',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    advanceId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    groupId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    contributionId: {
      type: DataTypes.UUID,
      allowNull: false,
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
    recoveredAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'agent_group_advance_recoveries',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['advance_id', 'recovered_at'] },
      { fields: ['group_id', 'member_id', 'recovered_at'] },
      { fields: ['agent_profile_id', 'recovered_at'] },
    ],
  },
);

module.exports = AgentGroupAdvanceRecovery;
