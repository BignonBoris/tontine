const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');
const { normalizePhone, displayPhone } = require('../auth/auth.service');

function hashPin(pin) {
  return crypto.createHash('sha256').update(String(pin)).digest('hex');
}

function signAgentToken(user) {
  return jwt.sign(
    { sub: user.id, phoneNumber: user.phoneNumber, scope: 'agent' },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn },
  );
}

async function loginAgent({ phoneNumber, pin }, context = {}) {
  const normalizedPhone = normalizePhone(phoneNumber);
  if (normalizedPhone.length !== 8) {
    throw new AppError('Le numero agent est invalide.', 422);
  }
  if (!pin || String(pin).trim().length < 4) {
    throw new AppError('Le code PIN agent est invalide.', 422);
  }

  const user = await models.User.findOne({
    where: { phoneNumber: normalizedPhone, isActive: true },
    include: [{ model: models.AgentProfile, as: 'agentProfile' }],
  });

  if (!user || !user.agentProfile || !user.agentProfile.isActive) {
    await writeAuditLog({
      action: 'agent.login_failed',
      entityType: 'agent',
      status: 'failed',
      ipAddress: context.ipAddress || null,
      userAgent: context.userAgent || null,
      metadata: { phoneNumber: normalizedPhone, reason: 'agent_not_found' },
    });
    throw new AppError('Compte agent introuvable ou inactif.', 401);
  }

  if (user.agentProfile.pinHash !== hashPin(pin)) {
    await writeAuditLog({
      userId: user.id,
      action: 'agent.login_failed',
      entityType: 'agent',
      entityId: user.agentProfile.id,
      status: 'failed',
      ipAddress: context.ipAddress || null,
      userAgent: context.userAgent || null,
      metadata: { phoneNumber: normalizedPhone, reason: 'invalid_pin' },
    });
    throw new AppError('Numero ou PIN agent incorrect.', 401);
  }

  await user.update({ lastLoginAt: new Date() });
  await writeAuditLog({
    userId: user.id,
    action: 'agent.login_success',
    entityType: 'agent',
    entityId: user.agentProfile.id,
    status: 'success',
    ipAddress: context.ipAddress || null,
    userAgent: context.userAgent || null,
    metadata: { phoneNumber: normalizedPhone },
  });

  return {
    token: signAgentToken(user),
    agent: {
      id: user.agentProfile.id,
      userId: user.id,
      phoneNumber: displayPhone(user.phoneNumber),
      fullName: user.agentProfile.fullName,
      agentCode: user.agentProfile.agentCode,
      agentBalance: Number(user.agentProfile.agentBalance || 0),
    },
  };
}

module.exports = { loginAgent, hashPin };
