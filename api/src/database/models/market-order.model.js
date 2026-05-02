const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { MARKET_ORDER_STATUSES } = require('../../common/constants/enums');

const MarketOrder = sequelize.define(
  'MarketOrder',
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
    offerId: {
      type: DataTypes.STRING(64),
      allowNull: false,
    },
    title: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    quantity: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 1,
      validate: {
        min: 1,
      },
    },
    unitPrice: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0,
      },
    },
    status: {
      type: DataTypes.ENUM(...MARKET_ORDER_STATUSES),
      allowNull: false,
      defaultValue: 'pending',
    },
    orderedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    updatedStatusAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'market_orders',
    indexes: [
      { fields: ['user_id', 'status'] },
      { fields: ['user_id', 'ordered_at'] },
      { fields: ['offer_id'] },
    ],
  },
);

module.exports = MarketOrder;
