const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { OTP_PURPOSES } = require('../../common/constants/enums');

const AuthOtp = sequelize.define(
  'AuthOtp',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    phoneNumber: {
      type: DataTypes.STRING(32),
      allowNull: false,
    },
    purpose: {
      type: DataTypes.ENUM(...OTP_PURPOSES),
      allowNull: false,
    },
    code: {
      type: DataTypes.STRING(8),
      allowNull: false,
    },
    attemptCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    resendCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    lastSentAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    blockedUntil: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    consumedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'auth_otps',
    indexes: [
      { fields: ['phone_number', 'purpose'] },
      { fields: ['phone_number', 'purpose', 'consumed_at'] },
      { fields: ['expires_at'] },
      { fields: ['blocked_until'] },
    ],
  },
);

module.exports = AuthOtp;
