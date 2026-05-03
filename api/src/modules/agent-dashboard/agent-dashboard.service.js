const { Op, fn, col } = require('sequelize');
const { models } = require('../../database/models');

function startOfDay() {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date;
}

async function getOverview(agentProfileId) {
  const today = startOfDay();
  const [operationsToday, amountRow, pendingCount, myClientsCount] = await Promise.all([
    models.Provisioning.count({
      where: {
        agentProfileId,
        createdAt: { [Op.gte]: today },
      },
    }),
    models.Provisioning.findOne({
      where: {
        agentProfileId,
        createdAt: { [Op.gte]: today },
      },
      attributes: [[fn('COALESCE', fn('SUM', col('amount')), 0), 'totalAmount']],
      raw: true,
    }),
    models.Provisioning.count({
      where: {
        agentProfileId,
        status: { [Op.in]: ['initiated', 'pending_validation'] },
      },
    }),
    models.User.count({
      where: {
        createdByAgentProfileId: agentProfileId,
        isActive: true,
        accountType: { [Op.ne]: 'Agent' },
      },
    }),
  ]);

  return {
    operationsToday,
    pendingCount,
    totalAmountToday: Number(amountRow?.totalAmount || 0),
    myClientsCount,
  };
}

module.exports = { getOverview };
