const AppError = require('../errors/app-error');
const { models } = require('../../database/models');

async function authenticateAgent(req, res, next) {
  if (!req.auth?.userId) {
    return next(new AppError('Authentification agent requise.', 401));
  }

  const agentProfile = await models.AgentProfile.findOne({
    where: { userId: req.auth.userId, isActive: true },
  });

  if (!agentProfile) {
    return next(new AppError('Compte agent invalide ou inactif.', 403));
  }

  req.agentProfile = agentProfile;
  return next();
}

module.exports = authenticateAgent;
