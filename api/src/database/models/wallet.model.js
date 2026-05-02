const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const Wallet = sequelize.define(
  'Wallet',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    userId: {
      type: DataTypes.UUID,
      allowNull: false,
      unique: true,
    },
    availableBalance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    tontineBalance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
  },
  {
    tableName: 'wallets',
    indexes: [{ unique: true, fields: ['user_id'] }],
  },
);

module.exports = Wallet;
