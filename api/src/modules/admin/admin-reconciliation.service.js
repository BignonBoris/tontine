const { models } = require('../../database/models');
const { Sequelize } = require('sequelize');

/**
 * Runs a financial reconciliation (Audit) of the whole system.
 * Compares total liabilities (user balances, commissions, goals) 
 * against physical assets (cash collected by agents).
 * The difference represents the required bank reserve.
 */
async function runReconciliation() {
  // 1. Total Liabilities (What we owe to users & agents/platform)
  
  // Wallet Balances
  const walletSum = await models.Wallet.findOne({
    attributes: [
      [Sequelize.fn('SUM', Sequelize.col('available_balance')), 'totalAvailable'],
      [Sequelize.fn('SUM', Sequelize.col('reserved_withdrawal_balance')), 'totalReserved'],
      [Sequelize.fn('SUM', Sequelize.col('tontine_balance')), 'totalTontine'],
    ],
    raw: true,
  });

  // Goal Balances
  const goalSum = await models.Goal.findOne({
    attributes: [
      [Sequelize.fn('SUM', Sequelize.col('current_amount')), 'totalGoalAmount'],
    ],
    where: {
      status: 'active',
    },
    raw: true,
  });

  // Commission Wallets
  const commSum = await models.CommissionWallet.findOne({
    attributes: [
      [Sequelize.fn('SUM', Sequelize.col('balance')), 'totalCommission'],
      [Sequelize.fn('SUM', Sequelize.col('payable_balance')), 'totalPayable'],
    ],
    raw: true,
  });

  // 2. Total Assets in Agents' hands
  const agentCashSum = await models.AgentProfile.findOne({
    attributes: [
      [Sequelize.fn('SUM', Sequelize.col('agent_balance')), 'totalAgentCash'],
    ],
    raw: true,
  });
  
  const parseAmount = (val) => {
    if (!val) return 0;
    const parsed = parseFloat(val);
    return isNaN(parsed) ? 0 : parsed;
  };

  const liabilities = {
    userAvailable: parseAmount(walletSum?.totalAvailable),
    userReserved: parseAmount(walletSum?.totalReserved),
    userTontine: parseAmount(walletSum?.totalTontine),
    userGoals: parseAmount(goalSum?.totalGoalAmount),
    commissions: parseAmount(commSum?.totalCommission),
    commissionsPayable: parseAmount(commSum?.totalPayable),
  };

  const totalLiabilities = 
    liabilities.userAvailable + 
    liabilities.userReserved + 
    liabilities.userTontine + 
    liabilities.userGoals + 
    liabilities.commissions + 
    liabilities.commissionsPayable;

  const assets = {
    agentCash: parseAmount(agentCashSum?.totalAgentCash),
  };

  // The required bank balance is what should be in the real bank account to cover everything.
  const requiredBankReserve = totalLiabilities - assets.agentCash;

  return {
    timestamp: new Date(),
    liabilities,
    totalLiabilities,
    assets,
    requiredBankReserve,
    isHealthy: requiredBankReserve >= 0,
  };
}

module.exports = {
  runReconciliation,
};
