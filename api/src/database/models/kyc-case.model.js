const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const KycCase = sequelize.define(
  'KycCase',
  {
    id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
    userId: { type: DataTypes.UUID, allowNull: false },
    status: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'unverified' },
    level: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'basic' },
    submittedAt: { type: DataTypes.DATE, allowNull: true },
    reviewedAt: { type: DataTypes.DATE, allowNull: true },
    expiresAt: { type: DataTypes.DATE, allowNull: true },
    rejectionReason: { type: DataTypes.STRING(500), allowNull: true },
    metadata: { type: DataTypes.JSON, allowNull: true },
  },
  { tableName: 'kyc_cases', indexes: [{ fields: ['user_id'], unique: true }, { fields: ['status'] }] },
);

module.exports = KycCase;
