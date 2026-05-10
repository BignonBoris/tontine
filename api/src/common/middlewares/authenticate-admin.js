const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const AppError = require('../errors/app-error');

function authenticateAdmin(req, res, next) {
  const header = req.headers.authorization || '';
  const [type, token] = header.split(' ');

  if (type !== 'Bearer' || !token) {
    return next(new AppError('Authentification admin requise.', 401));
  }

  try {
    const payload = jwt.verify(token, env.jwtSecret);
    const isLegacyToken =
      payload.type === 'admin' && payload.role === 'admin';
    const isCurrentToken =
      payload.kind === 'admin' && payload.username === env.adminUsername;

    if (!isLegacyToken && !isCurrentToken) {
      throw new AppError('Jeton admin invalide ou expire.', 401);
    }

    const username =
      payload.username || payload.sub || env.adminUsername;

    req.admin = {
      username,
      role: 'admin',
    };
    req.adminAuth = {
      kind: 'admin',
      username,
    };
    return next();
  } catch (error) {
    return next(
      error instanceof AppError
        ? error
        : new AppError('Jeton admin invalide ou expire.', 401),
    );
  }
}

module.exports = authenticateAdmin;
