const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  TONTINE_PAYMENT_INTENT_STATUSES,
} = require('../../common/constants/enums');

const TontinePaymentIntent = sequelize.define(
  'TontinePaymentIntent',
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
    cycleId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0,
      },
    },
    provider: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'fedapay',
    },
    merchantReference: {
      type: DataTypes.STRING(80),
      allowNull: false,
      unique: true,
    },
    providerTransactionId: {
      type: DataTypes.STRING(80),
      allowNull: true,
    },
    paymentUrl: {
      type: DataTypes.STRING(512),
      allowNull: true,
    },
    callbackUrl: {
      type: DataTypes.STRING(512),
      allowNull: true,
    },
    status: {
      type: DataTypes.ENUM(...TONTINE_PAYMENT_INTENT_STATUSES),
      allowNull: false,
      defaultValue: 'pending',
    },
    providerStatus: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    providerPayload: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    failureReason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    depositHistoryId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    initiatedByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    initiatorType: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    approvedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    processedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    failedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    cancelledAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    expiredAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    // 'redirect' (page de paiement FedaPay) ou 'push' (push USSD sans redirection)
    channel: {
      type: DataTypes.STRING(16),
      allowNull: false,
      defaultValue: 'redirect',
    },
    pushOperator: {
      type: DataTypes.STRING(16),
      allowNull: true,
    },
    pushMode: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    // Seule une version masquee du numero est conservee (ex. 01••••••90)
    pushPhoneMasked: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    pushSentAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    lastErrorCode: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
  },
  {
    tableName: 'tontine_payment_intents',
    indexes: [
      { fields: ['merchant_reference'], unique: true },
      { fields: ['user_id', 'status', 'created_at'] },
      { fields: ['cycle_id', 'status', 'created_at'] },
      { fields: ['provider_transaction_id'] },
      { fields: ['deposit_history_id'] },
    ],
  },
);

module.exports = TontinePaymentIntent;
