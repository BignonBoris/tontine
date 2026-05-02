const { ensureAuthOtpCompatibility } = require('./auth-otp.bootstrap');

async function runBootstrap(sequelize) {
  await ensureAuthOtpCompatibility(sequelize);
}

module.exports = runBootstrap;
