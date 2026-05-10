const { ensureAuthOtpCompatibility } = require('./auth-otp.bootstrap');
const { ensureAgentProfileCompatibility } = require('./agent-profile.bootstrap');
const { ensureWithdrawalCompatibility } = require('./withdrawal.bootstrap');
const { ensureWalletCompatibility } = require('./wallet.bootstrap');
const { ensureCommissionCompatibility } = require('./commission.bootstrap');
const { models } = require('../models');

async function runBootstrap(sequelize) {
  await ensureAuthOtpCompatibility(sequelize);
  await ensureAgentProfileCompatibility(sequelize);
  await ensureWalletCompatibility(sequelize);
  await ensureCommissionCompatibility(sequelize, models);
  await ensureWithdrawalCompatibility(sequelize);
}

module.exports = runBootstrap;
