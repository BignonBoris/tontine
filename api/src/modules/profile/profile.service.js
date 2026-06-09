const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');
const {
  displayPhone,
  normalizePhone,
  normalizeDisplayName,
  isValidDisplayName,
} = require('../auth/auth.service');

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
  if (payload.displayName != null) {
    const displayName = normalizeDisplayName(payload.displayName);
    if (!isValidDisplayName(displayName)) {
      throw new AppError('Le nom affiche est invalide.', 422);
    }
    updates.displayName = displayName;
  }
  if (payload.accountType) updates.accountType = payload.accountType;
  if (payload.phoneNumber != null) {
    const phoneNumber = normalizePhone(payload.phoneNumber);
    if (phoneNumber.length !== 10) {
      throw new AppError('Le numero de telephone est invalide.', 422);
    }
    updates.phoneNumber = phoneNumber;
  }

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
