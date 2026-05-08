const OTP_PURPOSES = ['register', 'login'];
const TONTINE_CYCLE_STATUSES = [
  'nonConfiguree',
  'active',
  'enAttenteValidationFin',
  'terminee',
  'arretee',
];
const GOAL_STATUSES = ['active', 'closed'];
const TONTINE_HISTORY_TYPES = [
  'configuration',
  'deposit',
  'cycleCompleted',
  'payoutConfirmed',
  'earlyStop',
  'restarted',
];
const TONTINE_ARCHIVE_STATUSES = ['completed', 'stoppedEarly'];
const AVAILABLE_BALANCE_HISTORY_TYPES = [
  'tontinePayout',
  'tontineEarlyStop',
  'goalFunding',
  'tontineFunding',
  'withdrawalRequested',
  'withdrawalCancelled',
];
const APP_NOTIFICATION_TYPES = [
  'deposit',
  'cycle',
  'goal',
  'marketplace',
  'system',
];
const MARKET_ORDER_STATUSES = [
  'pending',
  'confirmed',
  'ready',
  'completed',
  'cancelled',
];
const PROVISIONING_STATUSES = [
  'initiated',
  'pending_validation',
  'validated',
  'rejected',
  'cancelled',
];
const PROVISIONING_SOURCES = ['agent', 'mobile_money'];
const OPERATION_ACTOR_TYPES = ['agent', 'admin', 'client', 'system'];
const WITHDRAWAL_STATUSES = ['requested', 'paid', 'cancelled'];
const WITHDRAWAL_CHANNELS = ['agent_cash'];
const AGENT_BALANCE_HISTORY_TYPES = [
  'topUp',
  'clientDeposit',
  'clientWithdrawal',
  'adjustment',
];

module.exports = {
  OTP_PURPOSES,
  TONTINE_CYCLE_STATUSES,
  GOAL_STATUSES,
  TONTINE_HISTORY_TYPES,
  TONTINE_ARCHIVE_STATUSES,
  AVAILABLE_BALANCE_HISTORY_TYPES,
  APP_NOTIFICATION_TYPES,
  MARKET_ORDER_STATUSES,
  PROVISIONING_STATUSES,
  PROVISIONING_SOURCES,
  OPERATION_ACTOR_TYPES,
  WITHDRAWAL_STATUSES,
  WITHDRAWAL_CHANNELS,
  AGENT_BALANCE_HISTORY_TYPES,
};
