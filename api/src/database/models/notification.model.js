const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { APP_NOTIFICATION_TYPES } = require('../../common/constants/enums');

const Notification = sequelize.define(
  'Notification',
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
    type: {
      type: DataTypes.ENUM(...APP_NOTIFICATION_TYPES),
      allowNull: false,
      defaultValue: 'system',
    },
    title: {
      type: DataTypes.STRING(160),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    message: {
      type: DataTypes.STRING(255),
      allowNull: false,
      validate: {
        notEmpty: true,
      },
    },
    isRead: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    createdAtClient: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: 'notifications',
    indexes: [
      { fields: ['user_id', 'is_read'] },
      { fields: ['user_id', 'created_at_client'] },
      { fields: ['user_id', 'type'] },
    ],
  },
);

module.exports = Notification;
