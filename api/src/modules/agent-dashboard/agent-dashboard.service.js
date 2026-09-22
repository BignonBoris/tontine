const { Op, fn, col } = require('sequelize');
const { models } = require('../../database/models');

function startOfDay() {
  const date = new Date();
  date.setHours(0, 0, 0, 0);
  return date;
}

async function getOverview(agentProfileId) {
  const today = startOfDay();
  const [agentProfile, operationsToday, amountRow, pendingCount, myClientsCount, lastOperation] =
    await Promise.all([
      models.AgentProfile.findByPk(agentProfileId),
      models.Provisioning.count({
        where: {
          agentProfileId,
          status: 'validated',
          createdAt: { [Op.gte]: today },
        },
      }),
      models.Provisioning.findOne({
        where: {
          agentProfileId,
          status: 'validated',
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

      models.Provisioning.findOne({
        where: { agentProfileId },
        order: [['createdAt', 'DESC']],
        include: [{ model: models.User, as: 'client', attributes: ['firstName', 'lastName'] }],
      }),
    ]);

  return {
    agentBalance: Number(agentProfile?.agentBalance || 0),
    operationsToday,
    pendingCount,
    totalAmountToday: Number(amountRow?.totalAmount || 0),
    myClientsCount,
    lastOperation: lastOperation ? {
      id: lastOperation.id,
      reference: lastOperation.reference,
      amount: Number(lastOperation.amount),
      status: lastOperation.status,
      createdAt: lastOperation.createdAt,
      clientName: lastOperation.client ? 
          [lastOperation.client.firstName, lastOperation.client.lastName]
              .filter(Boolean)
              .join(' ') || 'Client inconnu' 
          : 'Client inconnu',
    } : null,
  };
}

module.exports = { getOverview };
