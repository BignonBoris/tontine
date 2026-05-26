const { ensureAuthOtpCompatibility } = require('./auth-otp.bootstrap');
const { ensureAgentProfileCompatibility } = require('./agent-profile.bootstrap');
const { ensureUserCompatibility } = require('./user.bootstrap');
const { ensureGoalCompatibility } = require('./goal.bootstrap');
const { ensureWithdrawalCompatibility } = require('./withdrawal.bootstrap');
const { ensureWalletCompatibility } = require('./wallet.bootstrap');
const { ensureCommissionCompatibility } = require('./commission.bootstrap');
const { ensureMarketOfferCompatibility } = require('./market-offer.bootstrap');
const { ensureAgentGroupCompatibility } = require('./agent-group.bootstrap');
const { ensureAgentGroupMemberCompatibility } = require('./agent-group-member.bootstrap');
const { ensureAgentGroupContributionCompatibility } = require('./agent-group-contribution.bootstrap');
const { models } = require('../models');

async function runBootstrap(sequelize) {
  await ensureAuthOtpCompatibility(sequelize);
  await ensureAgentProfileCompatibility(sequelize);
  await ensureUserCompatibility(sequelize);
  await ensureWalletCompatibility(sequelize);
  await ensureGoalCompatibility(sequelize);
  await ensureCommissionCompatibility(sequelize, models);
  await ensureMarketOfferCompatibility(sequelize);
  await ensureWithdrawalCompatibility(sequelize);
  await ensureAgentGroupCompatibility(sequelize);
  await ensureAgentGroupMemberCompatibility(sequelize);
  await ensureAgentGroupContributionCompatibility(sequelize);
}

module.exports = runBootstrap;
