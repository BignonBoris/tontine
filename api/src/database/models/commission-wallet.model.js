const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const CommissionWallet = sequelize.define(
  'CommissionWallet',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    ownerType: {
      type: DataTypes.ENUM('agent', 'platform', 'client'),
      allowNull: false,
    },
    ownerId: {
      type: DataTypes.STRING(64),
      allowNull: false,
    },
    walletType: {
      type: DataTypes.ENUM(
        'agent_commission',
        'platform_commission',
        'platform_floating',
        'client_bonus',
      ),
      allowNull: false,
    },
    balance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    payableBalance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    blockedBalance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    currency: {
      type: DataTypes.STRING(8),
      allowNull: false,
      defaultValue: 'XOF',
    },
  },
  {
    tableName: 'commission_wallets',
    indexes: [
      { unique: true, fields: ['owner_type', 'owner_id', 'wallet_type'] },
      { fields: ['wallet_type'] },
    ],
  },
);

module.exports = CommissionWallet;
