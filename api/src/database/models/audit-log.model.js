const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const AuditLog = sequelize.define(
  'AuditLog',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    action: {
      type: DataTypes.STRING(120),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    entityType: {
      type: DataTypes.STRING(64),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    entityId: {
      type: DataTypes.STRING(128),
      allowNull: true,
    },
    status: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'success',
    },
    ipAddress: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    userAgent: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: true,
    },
  },
  {
    tableName: 'audit_logs',
    indexes: [
      { fields: ['user_id', 'created_at'] },
      { fields: ['action', 'created_at'] },
      { fields: ['entity_type', 'entity_id'] },
    ],
  },
);

module.exports = AuditLog;
