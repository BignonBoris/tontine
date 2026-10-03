const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const DeviceSession = sequelize.define('DeviceSession', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  userId: { type: DataTypes.UUID, allowNull: false },
  deviceId: { type: DataTypes.STRING(128), allowNull: false },
  status: { type: DataTypes.ENUM('active', 'revoked'), allowNull: false, defaultValue: 'active' },
  lastSeenAt: { type: DataTypes.DATE, allowNull: false },
  revokedAt: { type: DataTypes.DATE, allowNull: true },
}, {
  tableName: 'device_sessions',
  indexes: [{ fields: ['user_id', 'status'] }, { unique: true, fields: ['user_id', 'device_id', 'status'] }],
});

module.exports = DeviceSession;
