const { DataTypes } = require('sequelize');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureKycCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const timestamps = {
    created_at: { type: DataTypes.DATE, allowNull: false },
    updated_at: { type: DataTypes.DATE, allowNull: false },
  };

  if (!(await tableExists(queryInterface, 'kyc_cases'))) {
    await queryInterface.createTable('kyc_cases', {
      id: { type: DataTypes.UUID, primaryKey: true },
      user_id: { type: DataTypes.UUID, allowNull: false },
      status: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'unverified' },
      level: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'basic' },
      submitted_at: { type: DataTypes.DATE, allowNull: true },
      reviewed_at: { type: DataTypes.DATE, allowNull: true },
      expires_at: { type: DataTypes.DATE, allowNull: true },
      rejection_reason: { type: DataTypes.STRING(500), allowNull: true },
      metadata: { type: DataTypes.JSON, allowNull: true },
      ...timestamps,
    });
  }

  if (!(await tableExists(queryInterface, 'kyc_documents'))) {
    await queryInterface.createTable('kyc_documents', {
      id: { type: DataTypes.UUID, primaryKey: true },
      kyc_case_id: { type: DataTypes.UUID, allowNull: false },
      document_type: { type: DataTypes.STRING(40), allowNull: false },
      country_code: { type: DataTypes.STRING(2), allowNull: false, defaultValue: 'BJ' },
      document_number: { type: DataTypes.STRING(120), allowNull: true },
      storage_key: { type: DataTypes.STRING(500), allowNull: true },
      status: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'submitted' },
      submitted_at: { type: DataTypes.DATE, allowNull: false },
      metadata: { type: DataTypes.JSON, allowNull: true },
      ...timestamps,
    });
  }

  if (!(await tableExists(queryInterface, 'kyc_decisions'))) {
    await queryInterface.createTable('kyc_decisions', {
      id: { type: DataTypes.UUID, primaryKey: true },
      kyc_case_id: { type: DataTypes.UUID, allowNull: false },
      decision: { type: DataTypes.STRING(32), allowNull: false },
      reason: { type: DataTypes.STRING(500), allowNull: true },
      decided_by: { type: DataTypes.STRING(120), allowNull: false },
      decided_at: { type: DataTypes.DATE, allowNull: false },
      metadata: { type: DataTypes.JSON, allowNull: true },
      ...timestamps,
    });
  }
}

module.exports = { ensureKycCompatibility };
