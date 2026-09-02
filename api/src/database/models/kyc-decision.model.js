const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const KycDecision = sequelize.define(
  'KycDecision',
  {
    id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
    kycCaseId: { type: DataTypes.UUID, allowNull: false },
    decision: { type: DataTypes.STRING(32), allowNull: false },
    reason: { type: DataTypes.STRING(500), allowNull: true },
    decidedBy: { type: DataTypes.STRING(120), allowNull: false },
    decidedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    metadata: { type: DataTypes.JSON, allowNull: true },
  },
  { tableName: 'kyc_decisions', indexes: [{ fields: ['kyc_case_id', 'decided_at'] }] },
);

module.exports = KycDecision;
