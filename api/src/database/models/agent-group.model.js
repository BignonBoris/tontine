const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  AGENT_GROUP_STATUSES,
  AGENT_GROUP_LAUNCH_STATUSES,
  AGENT_GROUP_TURN_UNITS,
} = require('../../common/constants/enums');

const AgentGroup = sequelize.define(
  'AgentGroup',
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
    agentProfileId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    name: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    normalizedName: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    description: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    participantCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      validate: {
        min: 2,
      },
    },
    memberCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    turnIntervalValue: {
      type: DataTypes.INTEGER,
      allowNull: false,
      validate: {
        min: 1,
      },
    },
    turnIntervalUnit: {
      type: DataTypes.ENUM(...AGENT_GROUP_TURN_UNITS),
      allowNull: false,
    },
    contributionAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    plannedStartDate: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    launchStatus: {
      type: DataTypes.ENUM(...AGENT_GROUP_LAUNCH_STATUSES),
      allowNull: false,
      defaultValue: 'collecting',
    },
    startedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    launchCancelledAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    launchCancellationReason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM(...AGENT_GROUP_STATUSES),
      allowNull: false,
      defaultValue: 'active',
    },
  },
  {
    tableName: 'agent_groups',
    indexes: [
      { unique: true, fields: ['reference'] },
      { unique: true, fields: ['agent_profile_id', 'normalized_name'] },
      { fields: ['agent_profile_id', 'status', 'created_at'] },
      { fields: ['agent_profile_id', 'turn_interval_unit', 'created_at'] },
      { fields: ['launch_status', 'planned_start_date'] },
      { fields: ['status', 'created_at'] },
    ],
  },
);

module.exports = AgentGroup;
