const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { AGENT_GROUP_MEMBER_STATUSES } = require('../../common/constants/enums');

const AgentGroupMember = sequelize.define(
  'AgentGroupMember',
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
    clientUserId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM(...AGENT_GROUP_MEMBER_STATUSES),
      allowNull: false,
      defaultValue: 'invited',
    },
    joinedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    turnPosition: {
      type: DataTypes.INTEGER,
      allowNull: true,
      validate: {
        min: 1,
      },
    },
    removedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    removalReason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    addedByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    removedByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
  },
  {
    tableName: 'agent_group_members',
    indexes: [
      { unique: true, fields: ['group_id', 'client_user_id'] },
      { fields: ['group_id', 'turn_position'] },
      { fields: ['group_id', 'status', 'created_at'] },
      { fields: ['client_user_id', 'status', 'created_at'] },
    ],
  },
);

module.exports = AgentGroupMember;
