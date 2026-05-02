const dotenv = require('dotenv');

dotenv.config();

const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  appName: process.env.APP_NAME || 'maTontine API',
  appBaseUrl: process.env.APP_BASE_URL || 'http://localhost:3000',
  jwtSecret: process.env.JWT_SECRET || 'change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  otpExpiresInMinutes: Number(process.env.OTP_EXPIRES_IN_MINUTES || 2),
  otpMaxAttempts: Number(process.env.OTP_MAX_ATTEMPTS || 5),
  otpMaxResends: Number(process.env.OTP_MAX_RESENDS || 3),
  otpBlockMinutes: Number(process.env.OTP_BLOCK_MINUTES || 10),
  otpResendCooldownSeconds: Number(
    process.env.OTP_RESEND_COOLDOWN_SECONDS || 30,
  ),
  swaggerEnabled: process.env.SWAGGER_ENABLED !== 'false',
  sequelizeSync: process.env.SEQUELIZE_SYNC !== 'false',
  database: {
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    name: process.env.DB_NAME || 'matontine_mvp',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
  },
};

module.exports = env;
