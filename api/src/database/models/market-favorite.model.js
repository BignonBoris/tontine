const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const MarketFavorite = sequelize.define(
  'MarketFavorite',
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
  },
  {
    tableName: 'market_favorites',
    indexes: [
      { unique: true, fields: ['user_id', 'offer_id'] },
      { fields: ['user_id', 'created_at'] },
    ],
  },
);

module.exports = MarketFavorite;
