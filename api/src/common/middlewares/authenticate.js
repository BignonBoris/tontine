const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const AppError = require('../errors/app-error');
const { models } = require('../../database/models');

async function authenticate(req, res, next) {
  const header = req.headers.authorization || '';
  const [type, token] = header.split(' ');

  if (type !== 'Bearer' || !token) {
    return next(new AppError('Authentification requise.', 401));
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret);
    const user = await models.User.findByPk(payload.sub);
    if (!user || !user.isActive) {
      throw new AppError('Utilisateur invalide ou inactif.', 401);
    }
    req.auth = {
      userId: user.id,
      phoneNumber: user.phoneNumber,
      accountType: user.accountType,
    };
    req.user = user;
    return next();
  } catch (error) {
    return next(
      error instanceof AppError
        ? error
        : new AppError('Jeton invalide ou expire.', 401),
    );
  }
}

module.exports = authenticate;
