const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  PAYMENT_METHOD_OPERATIONS,
  PAYMENT_METHOD_FLOW_TYPES,
} = require('../../modules/payment-methods/payment-methods.constants');

const PaymentMethod = sequelize.define(
  'PaymentMethod',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    code: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },
    label: {
      type: DataTypes.STRING(120),
      allowNull: false,
    },
    description: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    provider: {
      type: DataTypes.STRING(64),
      allowNull: false,
      defaultValue: 'internal',
    },
    operation: {
      type: DataTypes.STRING(32),
      allowNull: false,
      validate: {
        isIn: [PAYMENT_METHOD_OPERATIONS],
      },
    },
    flowType: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'internal_transfer',
      validate: {
        isIn: [PAYMENT_METHOD_FLOW_TYPES],
      },
    },
    enabled: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    metadata: {
      type: DataTypes.JSON,
      allowNull: true,
    },
  },
  {
    tableName: 'payment_methods',
    indexes: [
      { fields: ['code'], unique: true },
      { fields: ['operation', 'enabled', 'sort_order'] },
      { fields: ['sort_order'] },
    ],
  },
);

module.exports = PaymentMethod;
