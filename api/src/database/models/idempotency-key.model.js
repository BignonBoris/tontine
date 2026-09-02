const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const IdempotencyKey = sequelize.define(
  'IdempotencyKey',
  {
    key: {
      type: DataTypes.STRING(255),
      primaryKey: true,
      allowNull: false,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    path: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    requestBody: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    responseBody: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    responseCode: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM('PROCESSING', 'COMPLETED', 'ERROR'),
      allowNull: false,
      defaultValue: 'PROCESSING',
    },
    expiresAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  {
    tableName: 'idempotency_keys',
    timestamps: true,
    indexes: [
      { fields: ['expires_at'] },
    ],
  },
);

module.exports = IdempotencyKey;
