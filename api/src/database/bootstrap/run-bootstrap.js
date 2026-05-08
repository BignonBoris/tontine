const { ensureAuthOtpCompatibility } = require('./auth-otp.bootstrap');
const { ensureCommissionCompatibility } = require('./commission.bootstrap');
const { models } = require('../models');

async function runBootstrap(sequelize) {
  await ensureAuthOtpCompatibility(sequelize);
  await ensureCommissionCompatibility(sequelize, models);
}

module.exports = runBootstrap;
