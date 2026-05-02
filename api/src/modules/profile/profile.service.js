const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');
const { displayPhone, normalizePhone } = require('../auth/auth.service');

async function getProfile(userId) {
  const user = await models.User.findByPk(userId, {
    include: [{ model: models.UserPreference, as: 'preferences' }],
  });
  if (!user) {
    throw new AppError('Utilisateur introuvable.', 404);
  }

  return {
    id: user.id,
    displayName: user.displayName,
    phoneNumber: displayPhone(user.phoneNumber),
    accountType: user.accountType,
    memberSince: user.memberSince,
    lastLoginAt: user.lastLoginAt,
    preferences: user.preferences,
  };
}

async function updateProfile(userId, payload, requestContext = {}) {
  const user = await models.User.findByPk(userId);
  if (!user) {
    throw new AppError('Utilisateur introuvable.', 404);
  }

  const updates = {};
  if (payload.displayName) updates.displayName = payload.displayName;
  if (payload.accountType) updates.accountType = payload.accountType;
  if (payload.phoneNumber) updates.phoneNumber = normalizePhone(payload.phoneNumber);

  await user.update(updates);
  await writeAuditLog({
    userId,
    action: 'profile.updated',
    entityType: 'user',
    entityId: user.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      updatedFields: Object.keys(updates),
    },
  });
  return getProfile(userId);
}

async function updatePreferences(userId, payload, requestContext = {}) {
  const [preferences] = await models.UserPreference.findOrCreate({
    where: { userId },
    defaults: { userId },
  });
  await preferences.update(payload);
  await writeAuditLog({
    userId,
    action: 'profile.preferencesUpdated',
    entityType: 'userPreference',
    entityId: preferences.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      updatedFields: Object.keys(payload),
    },
  });
  return preferences;
}

module.exports = { getProfile, updateProfile, updatePreferences };
