const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');
const {
  displayPhone,
  hashClientPin,
  isValidPinCode,
  normalizePhone,
  normalizeDisplayName,
  isValidDisplayName,
  normalizePersonalName,
  isValidPersonalName,
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
    firstName: user.firstName,
    lastName: user.lastName,
    birthDate: user.birthDate,
    phoneNumber: displayPhone(user.phoneNumber),
    accountType: user.accountType,
    memberSince: user.memberSince,
    lastLoginAt: user.lastLoginAt,
    preferences: user.preferences
      ? {
          id: user.preferences.id,
          userId: user.preferences.userId,
          depositNotificationsEnabled:
              user.preferences.depositNotificationsEnabled,
          cycleNotificationsEnabled:
              user.preferences.cycleNotificationsEnabled,
          marketingNotificationsEnabled:
              user.preferences.marketingNotificationsEnabled,
          pinEnabled: user.preferences.pinEnabled,
          biometricEnabled: user.preferences.biometricEnabled,
        }
      : null,
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
  if (payload.firstName != null) {
    const firstName = normalizePersonalName(payload.firstName);
    if (!isValidPersonalName(firstName)) {
      throw new AppError('Le prenom est invalide.', 422);
    }
    updates.firstName = firstName;
  }
  if (payload.lastName != null) {
    const lastName = normalizePersonalName(payload.lastName);
    if (!isValidPersonalName(lastName)) {
      throw new AppError('Le nom est invalide.', 422);
    }
    updates.lastName = lastName;
  }
  if (payload.birthDate !== undefined) {
    if (payload.birthDate == null || `${payload.birthDate}`.trim().isEmpty) {
      updates.birthDate = null;
    } else {
      const parsed = new Date(payload.birthDate);
      if (Number.isNaN(parsed.getTime())) {
        throw new AppError('La date de naissance est invalide.', 422);
      }
      updates.birthDate = parsed.toISOString().slice(0, 10);
    }
  }
  if (payload.accountType) updates.accountType = payload.accountType;
  if (payload.phoneNumber != null) {
    const phoneNumber = normalizePhone(payload.phoneNumber);
    if (phoneNumber.length !== 10) {
      throw new AppError('Le numero de telephone est invalide.', 422);
    }
    updates.phoneNumber = phoneNumber;
  }
  if (updates.firstName != null || updates.lastName != null) {
    updates.displayName = normalizeDisplayName(
      `${updates.firstName ?? user.firstName ?? ''} ${updates.lastName ?? user.lastName ?? ''}`.trim(),
    ) || user.displayName;
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
  const updates = { ...payload };

  if (payload.pinCode !== undefined) {
    if (payload.pinCode == null || `${payload.pinCode}`.trim().isEmpty) {
      delete updates.pinCode;
    } else {
      if (!isValidPinCode(payload.pinCode)) {
        throw new AppError('Le code PIN doit contenir 4 chiffres.', 422);
      }
      updates.pinCode = hashClientPin(payload.pinCode);
      updates.pinEnabled = true;
    }
  }

  await preferences.update(updates);
  await writeAuditLog({
    userId,
    action: 'profile.preferencesUpdated',
    entityType: 'userPreference',
    entityId: preferences.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      updatedFields: Object.keys(updates),
    },
  });
  return {
    id: preferences.id,
    userId: preferences.userId,
    depositNotificationsEnabled: preferences.depositNotificationsEnabled,
    cycleNotificationsEnabled: preferences.cycleNotificationsEnabled,
    marketingNotificationsEnabled: preferences.marketingNotificationsEnabled,
    pinEnabled: preferences.pinEnabled,
    biometricEnabled: preferences.biometricEnabled,
  };
}

module.exports = { getProfile, updateProfile, updatePreferences };
