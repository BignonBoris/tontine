const sequelize = require('../../config/database');
const User = require('./user.model');
const UserPreference = require('./user-preference.model');
const AuthOtp = require('./auth-otp.model');
const AuditLog = require('./audit-log.model');
const AgentProfile = require('./agent-profile.model');
const AgentBalanceHistory = require('./agent-balance-history.model');
const Wallet = require('./wallet.model');
const Withdrawal = require('./withdrawal.model');
const TontineCycle = require('./tontine-cycle.model');
const TontineHistory = require('./tontine-history.model');
const TontineArchive = require('./tontine-archive.model');
const Goal = require('./goal.model');
const GoalTransaction = require('./goal-transaction.model');
const AvailableBalanceHistory = require('./available-balance-history.model');
const MarketOffer = require('./market-offer.model');
const MarketFavorite = require('./market-favorite.model');
const MarketOrder = require('./market-order.model');
const Notification = require('./notification.model');
const Provisioning = require('./provisioning.model');
const CommissionRule = require('./commission-rule.model');
const CycleCommissionSnapshot = require('./cycle-commission-snapshot.model');
const CommissionWallet = require('./commission-wallet.model');
const CommissionLedgerEntry = require('./commission-ledger-entry.model');
const WithdrawalCommissionReserve = require('./withdrawal-commission-reserve.model');
const WithdrawalCommissionConsumption = require('./withdrawal-commission-consumption.model');

User.hasOne(UserPreference, { foreignKey: 'userId', as: 'preferences' });
UserPreference.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(AuditLog, { foreignKey: 'userId', as: 'auditLogs' });
AuditLog.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasOne(AgentProfile, { foreignKey: 'userId', as: 'agentProfile' });
AgentProfile.belongsTo(User, { foreignKey: 'userId', as: 'user' });
AgentProfile.hasMany(User, {
  foreignKey: 'createdByAgentProfileId',
  as: 'createdClients',
});
User.belongsTo(AgentProfile, {
  foreignKey: 'createdByAgentProfileId',
  as: 'creatorAgent',
});

User.hasOne(Wallet, { foreignKey: 'userId', as: 'wallet' });
Wallet.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(Withdrawal, { foreignKey: 'userId', as: 'withdrawals' });
Withdrawal.belongsTo(User, { foreignKey: 'userId', as: 'user' });
AgentProfile.hasMany(Withdrawal, {
  foreignKey: 'paidByAgentProfileId',
  as: 'paidWithdrawals',
});
Withdrawal.belongsTo(AgentProfile, {
  foreignKey: 'paidByAgentProfileId',
  as: 'payingAgent',
});

User.hasMany(TontineCycle, { foreignKey: 'userId', as: 'tontineCycles' });
TontineCycle.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(TontineHistory, { foreignKey: 'userId', as: 'tontineHistory' });
TontineHistory.belongsTo(User, { foreignKey: 'userId', as: 'user' });
TontineCycle.hasMany(TontineHistory, { foreignKey: 'cycleId', as: 'history' });
TontineHistory.belongsTo(TontineCycle, { foreignKey: 'cycleId', as: 'cycle' });

User.hasMany(TontineArchive, { foreignKey: 'userId', as: 'tontineArchives' });
TontineArchive.belongsTo(User, { foreignKey: 'userId', as: 'user' });

User.hasMany(Goal, { foreignKey: 'userId', as: 'goals' });
Goal.belongsTo(User, { foreignKey: 'userId', as: 'user' });
Goal.hasMany(GoalTransaction, { foreignKey: 'goalId', as: 'transactions' });
GoalTransaction.belongsTo(Goal, { foreignKey: 'goalId', as: 'goal' });

User.hasMany(AvailableBalanceHistory, {
  foreignKey: 'userId',
  as: 'availableBalanceHistory',
});
AvailableBalanceHistory.belongsTo(User, { foreignKey: 'userId', as: 'user' });

MarketOffer.hasMany(Goal, { foreignKey: 'linkedOfferId', as: 'linkedGoals' });
Goal.belongsTo(MarketOffer, { foreignKey: 'linkedOfferId', as: 'linkedOffer' });

User.hasMany(MarketFavorite, { foreignKey: 'userId', as: 'marketFavorites' });
MarketFavorite.belongsTo(User, { foreignKey: 'userId', as: 'user' });
MarketOffer.hasMany(MarketFavorite, { foreignKey: 'offerId', as: 'favorites' });
MarketFavorite.belongsTo(MarketOffer, { foreignKey: 'offerId', as: 'offer' });

User.hasMany(MarketOrder, { foreignKey: 'userId', as: 'marketOrders' });
MarketOrder.belongsTo(User, { foreignKey: 'userId', as: 'user' });
MarketOffer.hasMany(MarketOrder, { foreignKey: 'offerId', as: 'orders' });
MarketOrder.belongsTo(MarketOffer, { foreignKey: 'offerId', as: 'offer' });

User.hasMany(Notification, { foreignKey: 'userId', as: 'notifications' });
Notification.belongsTo(User, { foreignKey: 'userId', as: 'user' });

AgentProfile.hasMany(Provisioning, {
  foreignKey: 'agentProfileId',
  as: 'provisionings',
});
Provisioning.belongsTo(AgentProfile, {
  foreignKey: 'agentProfileId',
  as: 'agentProfile',
});
User.hasMany(Provisioning, {
  foreignKey: 'clientUserId',
  as: 'clientProvisionings',
});
Provisioning.belongsTo(User, { foreignKey: 'clientUserId', as: 'client' });
User.hasMany(Provisioning, {
  foreignKey: 'validatedByUserId',
  as: 'validatedProvisionings',
});
Provisioning.belongsTo(User, {
  foreignKey: 'validatedByUserId',
  as: 'validator',
});

AgentProfile.hasMany(AgentBalanceHistory, {
  foreignKey: 'agentProfileId',
  as: 'balanceHistory',
});
AgentBalanceHistory.belongsTo(AgentProfile, {
  foreignKey: 'agentProfileId',
  as: 'agentProfile',
});

User.hasMany(CycleCommissionSnapshot, {
  foreignKey: 'userId',
  as: 'commissionSnapshots',
});
CycleCommissionSnapshot.belongsTo(User, { foreignKey: 'userId', as: 'user' });
TontineCycle.hasOne(CycleCommissionSnapshot, {
  foreignKey: 'tontineCycleId',
  as: 'commissionSnapshot',
});
CycleCommissionSnapshot.belongsTo(TontineCycle, {
  foreignKey: 'tontineCycleId',
  as: 'cycle',
});
CommissionRule.hasMany(CycleCommissionSnapshot, {
  foreignKey: 'commissionRuleId',
  as: 'snapshots',
});
CycleCommissionSnapshot.belongsTo(CommissionRule, {
  foreignKey: 'commissionRuleId',
  as: 'rule',
});

CommissionWallet.hasMany(CommissionLedgerEntry, {
  foreignKey: 'walletId',
  as: 'entries',
});
CommissionLedgerEntry.belongsTo(CommissionWallet, {
  foreignKey: 'walletId',
  as: 'wallet',
});

User.hasMany(WithdrawalCommissionReserve, {
  foreignKey: 'clientId',
  as: 'withdrawalCommissionReserves',
});
WithdrawalCommissionReserve.belongsTo(User, {
  foreignKey: 'clientId',
  as: 'client',
});
TontineCycle.hasMany(WithdrawalCommissionReserve, {
  foreignKey: 'cycleId',
  as: 'withdrawalCommissionReserves',
});
WithdrawalCommissionReserve.belongsTo(TontineCycle, {
  foreignKey: 'cycleId',
  as: 'cycle',
});
CycleCommissionSnapshot.hasMany(WithdrawalCommissionReserve, {
  foreignKey: 'snapshotId',
  as: 'withdrawalCommissionReserves',
});
WithdrawalCommissionReserve.belongsTo(CycleCommissionSnapshot, {
  foreignKey: 'snapshotId',
  as: 'snapshot',
});

WithdrawalCommissionReserve.hasMany(WithdrawalCommissionConsumption, {
  foreignKey: 'reserveId',
  as: 'consumptions',
});
WithdrawalCommissionConsumption.belongsTo(WithdrawalCommissionReserve, {
  foreignKey: 'reserveId',
  as: 'reserve',
});

const models = {
  User,
  UserPreference,
  AuthOtp,
  AuditLog,
  AgentProfile,
  AgentBalanceHistory,
  Wallet,
  Withdrawal,
  TontineCycle,
  TontineHistory,
  TontineArchive,
  Goal,
  GoalTransaction,
  AvailableBalanceHistory,
  MarketOffer,
  MarketFavorite,
  MarketOrder,
  Notification,
  Provisioning,
  CommissionRule,
  CycleCommissionSnapshot,
  CommissionWallet,
  CommissionLedgerEntry,
  WithdrawalCommissionReserve,
  WithdrawalCommissionConsumption,
};

module.exports = { sequelize, models };
