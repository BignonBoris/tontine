const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const AgentProfile = sequelize.define(
  'AgentProfile',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
    },
    agentCode: {
      type: DataTypes.STRING(32),
      allowNull: false,
      unique: true,
    },
    pinHash: {
      type: DataTypes.STRING(128),
      allowNull: false,
    },
    fullName: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  {
    tableName: 'agent_profiles',
    indexes: [
      { unique: true, fields: ['user_id'] },
      { unique: true, fields: ['agent_code'] },
      { fields: ['is_active'] },
    ],
  },
);

module.exports = AgentProfile;
