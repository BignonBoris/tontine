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
      field: 'user_id',
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
    agentBalance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    maxFloatLimit: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 500000,
      field: 'max_float_limit',
      validate: {
        min: 0,
      },
    },
    deviceId: {
      type: DataTypes.STRING,
      allowNull: true,
      field: 'device_id',
    },
    forceLogout: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'force_logout',
    },
  },
  {
    tableName: 'agent_profiles',
    indexes: [
      { unique: true, fields: ['user_id'] },
      { unique: true, fields: ['agent_code'] },
      { fields: ['agent_balance'] },
      { fields: ['is_active'] },
    ],
  },
);

module.exports = AgentProfile;
