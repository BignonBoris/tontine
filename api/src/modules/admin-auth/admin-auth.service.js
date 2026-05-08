const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');

async function login(payload, requestContext = {}) {
  const username = String(payload.username || '').trim();
  const password = String(payload.password || '');

  if (!username || !password) {
    throw new AppError("Nom d'utilisateur et mot de passe requis.", 422);
  }

  if (username !== env.adminUsername || password !== env.adminPassword) {
    await writeAuditLog({
      action: 'admin.login_failed',
      entityType: 'admin_session',
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        username,
      },
    });
    throw new AppError('Identifiants admin invalides.', 401);
  }

  const token = jwt.sign(
    {
      role: 'admin',
      type: 'admin',
    },
    env.jwtSecret,
    {
      subject: username,
      expiresIn: env.adminJwtExpiresIn,
    },
  );

  await writeAuditLog({
    action: 'admin.login_succeeded',
    entityType: 'admin_session',
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      username,
    },
  });

  return {
    token,
    admin: {
      username,
      role: 'admin',
    },
  };
}

function getSession(admin) {
  return {
    username: admin.username,
    role: admin.role,
  };
}

module.exports = {
  login,
  getSession,
};
