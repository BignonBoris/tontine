const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const KycDocument = sequelize.define(
  'KycDocument',
  {
    id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
    kycCaseId: { type: DataTypes.UUID, allowNull: false },
    documentType: { type: DataTypes.STRING(40), allowNull: false },
    countryCode: { type: DataTypes.STRING(2), allowNull: false, defaultValue: 'BJ' },
    documentNumber: { type: DataTypes.STRING(120), allowNull: true },
    storageKey: { type: DataTypes.STRING(500), allowNull: true },
    status: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'submitted' },
    submittedAt: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    metadata: { type: DataTypes.JSON, allowNull: true },
  },
  { tableName: 'kyc_documents', indexes: [{ fields: ['kyc_case_id'] }] },
);

module.exports = KycDocument;
