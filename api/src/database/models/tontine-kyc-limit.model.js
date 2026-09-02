const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const TontineKycLimit = sequelize.define(
  'TontineKycLimit',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    kycStatus: {
      type: DataTypes.STRING(32),
      allowNull: false,
      unique: true,
      comment: 'unverified, pending_review, verified',
    },
    tierLevel: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'tier_0',
      comment: 'tier_0, tier_1, tier_2',
    },
    label: {
      type: DataTypes.STRING(120),
      allowNull: false,
    },
    description: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    maxDailyStake: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 2000,
    },
    maxCycleCumulative: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 62000,
    },
    allowMultipleCycles: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    enabled: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    updatedBy: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
  },
  {
    tableName: 'tontine_kyc_limits',
    timestamps: true,
    indexes: [
      { fields: ['kyc_status'], unique: true },
      { fields: ['tier_level'] },
    ],
  },
);

module.exports = TontineKycLimit;
