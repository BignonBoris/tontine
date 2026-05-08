const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');

function signAdminToken() {
  return jwt.sign(
    {
      kind: 'admin',
      username: env.adminUsername,
    },
    env.jwtSecret,
    {
      expiresIn: env.adminJwtExpiresIn,
    },
  );
}

async function login(payload, requestContext = {}) {
  const username = String(payload?.username || '').trim();
  const password = String(payload?.password || '');

  if (!username || !password) {
    throw new AppError('Identifiants admin requis.', 422);
  }

  if (username !== env.adminUsername || password !== env.adminPassword) {
    await writeAuditLog({
      action: 'admin.login_failed',
      entityType: 'admin',
      entityId: username || 'unknown',
      status: 'failed',
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        username,
      },
    });
    throw new AppError('Identifiants admin invalides.', 401);
  }

  await writeAuditLog({
    action: 'admin.login_success',
    entityType: 'admin',
    entityId: username,
    status: 'success',
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      username,
    },
  });

  return {
    token: signAdminToken(),
    admin: {
      username: env.adminUsername,
    },
  };
}

module.exports = {
  login,
};
