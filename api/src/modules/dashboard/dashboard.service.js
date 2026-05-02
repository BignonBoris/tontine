const { models } = require('../../database/models');
const { serializeCycle } = require('../tontine/tontine.service');

async function getSummary(userId) {
  const [wallet, cycle, goals, notifications, orders, favorites] =
    await Promise.all([
      models.Wallet.findOne({ where: { userId } }),
      models.TontineCycle.findOne({
        where: { userId },
        order: [['createdAt', 'DESC']],
      }),
      models.Goal.findAll({ where: { userId, status: 'active' } }),
      models.Notification.findAll({
        where: { userId, isRead: false },
        order: [['createdAtClient', 'DESC']],
        limit: 5,
      }),
      models.MarketOrder.findAll({ where: { userId }, limit: 5, order: [['orderedAt', 'DESC']] }),
      models.MarketFavorite.count({ where: { userId } }),
    ]);

  const totalInGoals = goals.reduce(
    (sum, goal) => sum + Number(goal.currentAmount),
    0,
  );

  return {
    wallet,
    tontineCycle: serializeCycle(cycle),
    goals,
    totalInGoals,
    unreadNotifications: notifications.length,
    latestNotifications: notifications,
    recentOrders: orders,
    favoriteOffersCount: favorites,
  };
}

module.exports = { getSummary };
