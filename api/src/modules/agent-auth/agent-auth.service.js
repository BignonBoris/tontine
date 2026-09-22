const crypto = require('crypto');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');
const { normalizePhone, displayPhone } = require('../auth/auth.service');

async function hashAgentPin(pin) {
  return bcrypt.hash(String(pin), 12);
}

async function verifyAgentPin(pin, storedHash) {
  if (!storedHash) return false;
  if (storedHash.startsWith('$2b$') || storedHash.startsWith('$2a$')) {
    return bcrypt.compare(String(pin), storedHash);
  }
  const legacyHash = crypto.createHash('sha256').update(String(pin)).digest('hex');
  return legacyHash === storedHash;
}

function signAgentToken(user) {
  return jwt.sign(
    { sub: user.id, phoneNumber: user.phoneNumber, scope: 'agent' },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn },
  );
}

async function loginAgent({ phoneNumber, pin, deviceId }, context = {}) {
  const normalizedPhone = normalizePhone(phoneNumber);
  if (normalizedPhone.length !== 10) {
    throw new AppError('Le numero agent est invalide.', 422);
  }
  if (!pin || !/^\d{4}$/.test(String(pin).trim())) {
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

  const isPinValid = await verifyAgentPin(pin, user.agentProfile.pinHash);
  if (isPinValid && !user.agentProfile.pinHash.startsWith('$2b$')) {
    await user.agentProfile.update({ pinHash: await hashAgentPin(pin) });
  }
  if (!isPinValid) {
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

  // --- Sécurité et Liaison d'appareil ---
  const securitySettingsItem = await models.SystemSetting.findByPk('AGENT_SECURITY_SETTINGS');
  const settings = securitySettingsItem ? securitySettingsItem.value : {};
  const strictDeviceBinding = settings.agentStrictDeviceBinding ?? true;
  const otpDeviceBypass = settings.agentOtpDeviceBypass ?? false;
  const autoLockTimeoutMinutes = settings.agentAutoLockTimeoutMinutes ?? 2;

  if (deviceId) {
    if (!user.agentProfile.deviceId) {
      await user.agentProfile.update({ deviceId });
    } else if (user.agentProfile.deviceId !== deviceId && process.env.NODE_ENV !== 'development') {
      // Tentative de connexion sur un nouvel appareil
      if (strictDeviceBinding && !otpDeviceBypass) {
        await writeAuditLog({
          userId: user.id,
          action: 'agent.login_failed',
          entityType: 'agent',
          entityId: user.agentProfile.id,
          status: 'failed',
          metadata: { reason: 'unauthorized_device', deviceId },
        });
        throw new AppError("Cet appareil n'est pas autorise pour ce compte agent.", 403);
      } else if (otpDeviceBypass) {
        // Todo: implementer l'envoi d'OTP
        // return { requiresOtp: true, message: 'Un code de verification a ete envoye.' };
        // Pour l'instant on retourne une erreur 403 demandant de valider
        throw new AppError("Appareil inconnu. La validation par OTP sera bientot disponible. Veuillez contacter l'admin.", 403);
      }
    }
  }

  // Si on est connecté avec succès, on réinitialise le kill switch
  if (user.agentProfile.forceLogout) {
    await user.agentProfile.update({ forceLogout: false });
  }
  // --------------------------------------

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
      maxFloatLimit: Number(user.agentProfile.maxFloatLimit || 500000),
    },
    security: {
      autoLockTimeoutMinutes,
    }
  };
}

module.exports = { loginAgent, hashAgentPin, verifyAgentPin };
