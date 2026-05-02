const { models } = require('../../database/models');

async function getWallet(userId) {
  const wallet = await models.Wallet.findOne({ where: { userId } });
  const history = await models.AvailableBalanceHistory.findAll({
    where: { userId },
    order: [['occurredAt', 'DESC']],
  });
  return { wallet, history };
}

module.exports = { getWallet };
