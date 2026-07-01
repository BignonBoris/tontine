const { ensureAuthOtpCompatibility } = require('./auth-otp.bootstrap');
const { ensureAgentProfileCompatibility } = require('./agent-profile.bootstrap');
const { ensureUserCompatibility } = require('./user.bootstrap');
const {
  ensureUserPreferenceCompatibility,
} = require('./user-preference.bootstrap');
const { ensureGoalCompatibility } = require('./goal.bootstrap');
const { ensureWithdrawalCompatibility } = require('./withdrawal.bootstrap');
const { ensureWalletCompatibility } = require('./wallet.bootstrap');
const {
  ensureAvailableBalanceHistoryCompatibility,
} = require('./available-balance-history.bootstrap');
const {
  ensureTontineHistoryCompatibility,
} = require('./tontine-history.bootstrap');
const { ensureCommissionCompatibility } = require('./commission.bootstrap');
const { ensureMarketOfferCompatibility } = require('./market-offer.bootstrap');
const { ensureAgentGroupCompatibility } = require('./agent-group.bootstrap');
const { ensureAgentGroupMemberCompatibility } = require('./agent-group-member.bootstrap');
const { ensureAgentGroupTurnCompatibility } = require('./agent-group-turn.bootstrap');
const { ensureAgentGroupContributionCompatibility } = require('./agent-group-contribution.bootstrap');
const { ensureAgentGroupAdvanceCompatibility } = require('./agent-group-advance.bootstrap');
const { ensureAgentGroupAdvanceRecoveryCompatibility } = require('./agent-group-advance-recovery.bootstrap');
const {
  ensurePushDeviceTokenCompatibility,
} = require('./push-device-token.bootstrap');
const { models } = require('../models');

async function runBootstrap(sequelize) {
  await ensureAuthOtpCompatibility(sequelize);
  await ensureAgentProfileCompatibility(sequelize);
  await ensureUserCompatibility(sequelize);
  await ensureUserPreferenceCompatibility(sequelize);
  await ensureWalletCompatibility(sequelize);
  await ensureAvailableBalanceHistoryCompatibility(sequelize);
  await ensureTontineHistoryCompatibility(sequelize);
  await ensureGoalCompatibility(sequelize);
  await ensureCommissionCompatibility(sequelize, models);
  await ensureMarketOfferCompatibility(sequelize);
  await ensureWithdrawalCompatibility(sequelize);
  await ensureAgentGroupCompatibility(sequelize);
  await ensureAgentGroupMemberCompatibility(sequelize);
  await ensureAgentGroupTurnCompatibility(sequelize);
  await ensureAgentGroupContributionCompatibility(sequelize);
  await ensureAgentGroupAdvanceCompatibility(sequelize);
  await ensureAgentGroupAdvanceRecoveryCompatibility(sequelize);
  await ensurePushDeviceTokenCompatibility(sequelize);
}

module.exports = runBootstrap;
