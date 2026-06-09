const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const PushDeviceToken = sequelize.define(
  'PushDeviceToken',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    token: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
      validate: {
        notEmpty: true,
      },
    },
    platform: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'unknown',
    },
    appName: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'mobile',
    },
    deviceId: {
      type: DataTypes.STRING(128),
      allowNull: true,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    lastSeenAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'push_device_tokens',
    indexes: [
      { unique: true, fields: ['token'] },
      { fields: ['user_id', 'is_active', 'updated_at'] },
      { fields: ['user_id', 'app_name'] },
    ],
  },
);

module.exports = PushDeviceToken;
