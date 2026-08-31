const dotenv = require('dotenv');

dotenv.config();

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  appName: process.env.APP_NAME || 'maTontine API',
  appBaseUrl: process.env.APP_BASE_URL || 'http://localhost:3000',
  clientAppBaseUrl:
    process.env.CLIENT_APP_BASE_URL ||
    process.env.APP_BASE_URL ||
    'http://localhost:3000',
  jwtSecret: process.env.JWT_SECRET || 'change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  adminUsername: process.env.ADMIN_USERNAME || 'admin',
  adminPassword: process.env.ADMIN_PASSWORD || 'admin123',
  adminJwtExpiresIn: process.env.ADMIN_JWT_EXPIRES_IN || '12h',
  otpExpiresInMinutes: Number(process.env.OTP_EXPIRES_IN_MINUTES || 5),
  otpMaxAttempts: Number(process.env.OTP_MAX_ATTEMPTS || 3),
  otpMaxResends: Number(process.env.OTP_MAX_RESENDS || 3),
  otpBlockMinutes: Number(process.env.OTP_BLOCK_MINUTES || 15),
  otpResendCooldownSeconds: Number(
    process.env.OTP_RESEND_COOLDOWN_SECONDS || 120,
  ),
  swaggerEnabled: process.env.SWAGGER_ENABLED !== 'false',
  sequelizeSync: process.env.SEQUELIZE_SYNC === 'true',
  fcmServerKey: process.env.FCM_SERVER_KEY || '',
  fedapaySecretKey: process.env.FEDAPAY_SECRET_KEY || '',
  fedapayWebhookSecret: process.env.FEDAPAY_WEBHOOK_SECRET || '',
  fedapayApiBaseUrl:
    process.env.FEDAPAY_API_BASE_URL ||
    (process.env.FEDAPAY_ENV === 'live' || process.env.NODE_ENV === 'production'
      ? 'https://api.fedapay.com/v1'
      : 'https://sandbox-api.fedapay.com/v1'),
  afrikmoneyApiBaseUrl:
    process.env.AFRIKMONEY_API_BASE_URL || 'https://pay.afrikmoney.com',
  afrikmoneyApiKey: process.env.AFRIKMONEY_API_KEY || '',
  afrikmoneyWebhookSecret: process.env.AFRIKMONEY_WEBHOOK_SECRET || '',
  afrikmoneyCustomerEmailDomain:
    process.env.AFRIKMONEY_CUSTOMER_EMAIL_DOMAIN || 'example.com',
  mtnMomoEnv: process.env.MTN_MOMO_ENV || 'sandbox',
  mtnMomoApiBaseUrl:
    process.env.MTN_MOMO_API_BASE_URL ||
    (process.env.MTN_MOMO_ENV === 'live' || process.env.NODE_ENV === 'production'
      ? 'https://proxy.momoapi.mtn.com'
      : 'https://sandbox.momodeveloper.mtn.com'),
  mtnMomoTargetEnvironment:
    process.env.MTN_MOMO_TARGET_ENVIRONMENT || 'sandbox',
  mtnMomoCollectionSubscriptionKey:
    process.env.MTN_MOMO_COLLECTION_SUBSCRIPTION_KEY || '',
  mtnMomoApiUser: process.env.MTN_MOMO_API_USER || '',
  mtnMomoApiKey: process.env.MTN_MOMO_API_KEY || '',
  mtnMomoCurrency: process.env.MTN_MOMO_CURRENCY || 'EUR',
  mtnMomoCallbackBaseUrl:
    process.env.MTN_MOMO_CALLBACK_BASE_URL ||
    process.env.APP_BASE_URL ||
    'http://localhost:3000',
  mtnMomoMsisdnCountryCode: process.env.MTN_MOMO_MSISDN_COUNTRY_CODE || '',
  database: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    name: process.env.DB_NAME || 'matontine_mvp',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
  },
};

module.exports = env;
