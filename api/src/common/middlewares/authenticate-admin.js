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
    if (payload.type !== 'admin' || payload.role !== 'admin') {
      throw new AppError('Jeton admin invalide.', 401);
    }

    req.admin = {
      username: payload.sub,
      role: payload.role,
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
