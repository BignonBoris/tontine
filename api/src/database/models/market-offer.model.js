const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const MarketOffer = sequelize.define(
  'MarketOffer',
  {
    id: {
      type: DataTypes.STRING(64),
      primaryKey: true,
    },
    title: {
      type: DataTypes.STRING(160),
      allowNull: false,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    descriptionHtml: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    imageUrl: {
      type: DataTypes.STRING(255),
      allowNull: false,
    },
    category: {
      type: DataTypes.STRING(80),
      allowNull: false,
    },
    price: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: true,
    },
    brand: {
      type: DataTypes.STRING(120),
      allowNull: true,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  { tableName: 'market_offers' },
);

module.exports = MarketOffer;
