const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const { GOAL_STATUSES } = require('../../common/constants/enums');

const Goal = sequelize.define(
  'Goal',
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
    linkedOfferId: {
      type: DataTypes.STRING(64),
      allowNull: true,
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
      allowNull: true,
      validate: {
        min: 0,
      },
    },
    title: {
      type: DataTypes.STRING(160),
      allowNull: false,
      validate: {
        notEmpty: true,
        len: [3, 160],
      },
    },
    targetAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    currentAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
      validate: {
        min: 0,
      },
    },
    iconCodePoint: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    colorValue: {
      type: DataTypes.BIGINT,
      allowNull: false,
    },
    isPriority: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    status: {
      type: DataTypes.ENUM(...GOAL_STATUSES),
      allowNull: false,
      defaultValue: 'active',
    },
    startDate: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    endDate: {
      type: DataTypes.DATE,
      allowNull: false,
    },
  },
  {
    tableName: 'goals',
    indexes: [
      { fields: ['user_id', 'status'] },
      { fields: ['user_id', 'linked_offer_id'] },
      { fields: ['start_date'] },
      { fields: ['end_date'] },
    ],
  },
);

module.exports = Goal;
