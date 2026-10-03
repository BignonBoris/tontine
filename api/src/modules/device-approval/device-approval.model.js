const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const DeviceApprovalRequest = sequelize.define('DeviceApprovalRequest', {
  id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
  userId: { type: DataTypes.UUID, allowNull: false },
  requestingDeviceId: { type: DataTypes.STRING(128), allowNull: false },
  currentSessionId: { type: DataTypes.UUID, allowNull: true },
  status: { type: DataTypes.ENUM('pending', 'approved', 'rejected', 'expired'), allowNull: false, defaultValue: 'pending' },
  expiresAt: { type: DataTypes.DATE, allowNull: false },
  respondedAt: { type: DataTypes.DATE, allowNull: true },
  approvedByDeviceId: { type: DataTypes.STRING(128), allowNull: true },
}, {
  tableName: 'device_approval_requests',
  indexes: [{ fields: ['user_id', 'status'] }, { fields: ['user_id', 'created_at'] }],
});

module.exports = DeviceApprovalRequest;
