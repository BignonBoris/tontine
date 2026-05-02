const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { TONTINE_ARCHIVE_STATUSES } = require('../../common/constants/enums');

const TontineArchive = sequelize.define(
  'TontineArchive',
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
    stakeAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    targetAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    cumulativeAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    commissionAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    netPayoutAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM(...TONTINE_ARCHIVE_STATUSES),
      allowNull: false,
    },
    startedAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    expectedEndAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    endedAt: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  { tableName: 'tontine_archives' },
);

module.exports = TontineArchive;
