const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const crypto = require('crypto');
const { parsePhoneNumberWithError } = require('libphonenumber-js');
const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const whatsAppOtpService = require('../../common/services/whatsapp-otp.service');
const { models, sequelize } = require('../../database/models');

function validateAndNormalizePhone(phoneNumber, defaultCountry = 'BJ') {
  const rawStr = String(phoneNumber || '').trim();
  if (!rawStr) {
    throw new AppError('Le numéro de téléphone est obligatoire.', 422);
  }

  const digitsOnly = rawStr.replace(/\D/g, '');
  if (digitsOnly.length < 8 || /^(\d)\1+$/.test(digitsOnly)) {
    throw new AppError('Le numéro de téléphone fourni est invalide.', 422);
  }

  try {
    const parsed = parsePhoneNumberWithError(rawStr, defaultCountry);
    if (!parsed || !parsed.isValid()) {
      throw new AppError(
        'Numéro de téléphone invalide selon le plan de numérotation.',
        422,
      );
    }

    const nationalDigits = parsed.nationalNumber;
    const normalizedPhone =
      nationalDigits.length > 10 ? nationalDigits.slice(-10) : nationalDigits;

    return {
      normalizedPhone,
      e164: parsed.format('E.164'),
      country: parsed.country || defaultCountry,
      type: parsed.getType(),
    };
  } catch (error) {
    if (error instanceof AppError) {
      throw error;
    }
    if (digitsOnly.length === 10) {
      return {
        normalizedPhone: digitsOnly,
        e164: `+229${digitsOnly}`,
        country: defaultCountry,
        type: 'MOBILE',
      };
    }
    throw new AppError(
      'Numéro de téléphone invalide ou impossible à vérifier.',
      422,
    );
  }
}

function normalizePhone(phoneNumber) {
  try {
    const result = validateAndNormalizePhone(phoneNumber);
    return result.normalizedPhone;
  } catch {
    const digits = String(phoneNumber || '').replace(/\D/g, '');
    return digits.length > 10 ? digits.slice(-10) : digits;
  }
}

function displayPhone(phoneNumber) {
  const rawStr = String(phoneNumber || '').trim();
  if (!rawStr) {
    return 'Non renseigné';
  }
  try {
    const parsed = parsePhoneNumberWithError(rawStr, 'BJ');
    return parsed.formatInternational();
  } catch {
    return rawStr;
  }
}

function normalizeDisplayName(displayName) {
  return String(displayName || '')
    .replace(/\s+/g, ' ')
    .replace(/^[-'\s]+|[-'\s]+$/g, '')
    .trim();
}

function isValidDisplayName(displayName) {
  const normalized = normalizeDisplayName(displayName);
  return (
    normalized.length >= 3 &&
    /^[A-Za-z\u00C0-\u024F]/.test(normalized) &&
    !/\d/.test(normalized)
  );
}

function normalizePersonalName(name) {
  return normalizeDisplayName(name);
}

function isValidPersonalName(name) {
  const normalized = normalizePersonalName(name);
  return (
    normalized.length >= 2 &&
    /^[A-Za-z\u00C0-\u024F]/.test(normalized) &&
    !/\d/.test(normalized)
  );
}

function buildDisplayNameFromIdentity(firstName, lastName) {
  return normalizeDisplayName(`${firstName || ''} ${lastName || ''}`.trim());
}

function normalizeBirthDate(value) {
  if (value == null || String(value).trim().isEmpty) {
    return null;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new AppError('La date de naissance est invalide.', 422);
  }

  const today = new Date();
  const dateOnly = new Date(
    Date.UTC(parsed.getUTCFullYear(), parsed.getUTCMonth(), parsed.getUTCDate()),
  );
  const todayOnly = new Date(
    Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()),
  );

  if (dateOnly.getTime() > todayOnly.getTime()) {
    throw new AppError('La date de naissance ne peut pas etre dans le futur.', 422);
  }

  return dateOnly.toISOString().slice(0, 10);
}

function generateOtpCode() {
  return `${1000 + Math.floor(Math.random() * 9000)}`;
}

function hashClientPin(pinCode) {
  return crypto.createHash('sha256').update(String(pinCode || '')).digest('hex');
}

function isValidPinCode(pinCode) {
  return /^\d{4}$/.test(String(pinCode || '').trim());
}

function signToken(user) {
  return jwt.sign({ sub: user.id, phoneNumber: user.phoneNumber }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
}

function assertUserIsActive(user) {
  if (user && !user.isActive) {
    throw new AppError(
      'Votre compte est inactif. Contactez un administrateur.',
      403,
    );
  }
}

function computeExpiryDate() {
  return new Date(Date.now() + env.otpExpiresInMinutes * 60 * 1000);
}

function computeBlockDate() {
  return new Date(Date.now() + env.otpBlockMinutes * 60 * 1000);
}

function computeCooldownDate() {
  return new Date(Date.now() - env.otpResendCooldownSeconds * 1000);
}

function buildAuthContext(context = {}) {
  return {
    ipAddress: context.ipAddress || null,
    userAgent: context.userAgent || null,
  };
}

async function getLatestOtp(phoneNumber, purpose, transaction) {
  return models.AuthOtp.findOne({
    where: {
      phoneNumber,
      purpose,
      consumedAt: null,
    },
    order: [['createdAt', 'DESC']],
    transaction,
  });
}

async function getLatestOtpForVerification(phoneNumber) {
  return models.AuthOtp.findOne({
    where: {
      phoneNumber,
      consumedAt: null,
    },
    order: [['createdAt', 'DESC']],
  });
}

async function assertPhonePurposeConsistency(normalizedPhone, purpose) {
  const user = await models.User.findOne({
    where: { phoneNumber: normalizedPhone },
    include: [{ model: models.UserPreference, as: 'preferences' }],
  });

  if (purpose === 'register' && user) {
    throw new AppError(
      'Ce numero existe deja. Utilisez le parcours de connexion.',
      409,
    );
  }

  if (purpose === 'login' && !user) {
    throw new AppError('Aucun compte trouve pour ce numero.', 404);
  }

  return user;
}

function sanitizePreferences(preferences) {
  if (!preferences) {
    return null;
  }

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

async function createFreshOtp({
  normalizedPhone,
  purpose,
  authContext,
  transaction,
}) {
  await models.AuthOtp.update(
    { consumedAt: new Date() },
    {
      where: {
        phoneNumber: normalizedPhone,
        purpose,
        consumedAt: null,
      },
      transaction,
    },
  );

  const code = generateOtpCode();
  const otp = await models.AuthOtp.create(
    {
      phoneNumber: normalizedPhone,
      purpose,
      code,
      expiresAt: computeExpiryDate(),
      lastSentAt: new Date(),
      attemptCount: 0,
      resendCount: 0,
      blockedUntil: null,
    },
    { transaction },
  );

  await writeAuditLog({
    action: 'auth.otp.requested',
    entityType: 'auth_otp',
    entityId: otp.id,
    status: 'success',
    ipAddress: authContext.ipAddress,
    userAgent: authContext.userAgent,
    metadata: {
      phoneNumber: normalizedPhone,
      purpose,
    },
    transaction,
  });

  // Envoi asynchrone par WhatsApp si connecté
  whatsAppOtpService.sendOtp(normalizedPhone, code).catch((err) => {
    console.warn('[WhatsApp OTP Error]', err.message);
  });

  return {
    otpId: otp.id,
    phoneNumber: displayPhone(normalizedPhone),
    normalizedPhoneNumber: normalizedPhone,
    expiresAt: otp.expiresAt,
    debugOtpCode: code,
  };
}

async function requestOtp(payload, context) {
  const { phoneNumber, purpose, pinCode } = payload;
  const { normalizedPhone } = validateAndNormalizePhone(phoneNumber);
  const authContext = buildAuthContext(context);

  const user = await assertPhonePurposeConsistency(normalizedPhone, purpose);

  if (purpose === 'login') {
    assertUserIsActive(user);
  }

  if (purpose === 'login' && user?.preferences?.pinCode) {
    if (!isValidPinCode(pinCode)) {
      throw new AppError('Le code PIN doit contenir 4 chiffres.', 422);
    }

    const latestOtp = await getLatestOtp(normalizedPhone, purpose);
    if (
      latestOtp?.blockedUntil &&
      new Date(latestOtp.blockedUntil).getTime() > Date.now()
    ) {
      const minutesRemaining = Math.max(
        1,
        Math.ceil(
          (new Date(latestOtp.blockedUntil).getTime() - Date.now()) / (60 * 1000),
        ),
      );
      throw new AppError(
        `Trop de tentatives. Votre compte est suspendu. Veuillez réessayer dans ${minutesRemaining} minute(s).`,
        429,
      );
    }

    if (user.preferences.pinCode !== hashClientPin(pinCode)) {
      const currentAttempts = Number(latestOtp?.attemptCount || 0) + 1;
      const isMaxReached = currentAttempts >= env.otpMaxAttempts;
      const blockedUntil = isMaxReached ? computeBlockDate() : null;

      if (latestOtp) {
        await latestOtp.update({
          attemptCount: currentAttempts,
          blockedUntil,
        });
      } else {
        await models.AuthOtp.create({
          phoneNumber: normalizedPhone,
          purpose,
          code: '0000',
          expiresAt: computeExpiryDate(),
          lastSentAt: new Date(),
          attemptCount: currentAttempts,
          resendCount: 0,
          blockedUntil,
        });
      }

      await writeAuditLog({
        userId: user.id,
        action: 'auth.pin_failed',
        entityType: 'user',
        entityId: user.id,
        status: 'failed',
        ipAddress: authContext.ipAddress,
        userAgent: authContext.userAgent,
        metadata: {
          phoneNumber: normalizedPhone,
          attemptCount: currentAttempts,
          blockedUntil,
        },
      });

      if (isMaxReached) {
        throw new AppError(
          "Nombre maximal d'essais de PIN atteint (3/3). Votre compte est temporairement bloqué pendant 15 minutes.",
          429,
        );
      }

      const remaining = env.otpMaxAttempts - currentAttempts;
      throw new AppError(
        `Code PIN incorrect. Il vous reste ${remaining} essai(s) avant suspension du compte.`,
        401,
      );
    }
  }

  return sequelize.transaction(async (transaction) => {
    const existingOtp = await getLatestOtp(normalizedPhone, purpose, transaction);
    if (
      existingOtp?.blockedUntil &&
      new Date(existingOtp.blockedUntil).getTime() > Date.now()
    ) {
      throw new AppError(
        "Trop de tentatives. Reessayez plus tard pour recevoir un nouveau code.",
        429,
      );
    }

    return createFreshOtp({
      normalizedPhone,
      purpose,
      authContext,
      transaction,
    });
  });
}

async function resendOtp(payload, context) {
  const { phoneNumber, purpose } = payload;
  const { normalizedPhone } = validateAndNormalizePhone(phoneNumber);
  const authContext = buildAuthContext(context);

  await assertPhonePurposeConsistency(normalizedPhone, purpose);

  return sequelize.transaction(async (transaction) => {
    const otp = await getLatestOtp(normalizedPhone, purpose, transaction);
    if (!otp) {
      return createFreshOtp({
        normalizedPhone,
        purpose,
        authContext,
        transaction,
      });
    }

    if (otp.blockedUntil && new Date(otp.blockedUntil).getTime() > Date.now()) {
      throw new AppError(
        "Trop de tentatives. Reessayez plus tard pour recevoir un nouveau code.",
        429,
      );
    }

    if (
      otp.lastSentAt &&
      new Date(otp.lastSentAt).getTime() > computeCooldownDate().getTime()
    ) {
      throw new AppError(
        `Veuillez patienter ${env.otpResendCooldownSeconds} secondes avant de renvoyer un code.`,
        429,
      );
    }

    const nextResendCount = Number(otp.resendCount) + 1;
    if (nextResendCount > env.otpMaxResends) {
      await otp.update({ blockedUntil: computeBlockDate() }, { transaction });
      await writeAuditLog({
        action: 'auth.otp.resend_blocked',
        entityType: 'auth_otp',
        entityId: otp.id,
        status: 'blocked',
        ipAddress: authContext.ipAddress,
        userAgent: authContext.userAgent,
        metadata: {
          phoneNumber: normalizedPhone,
          purpose,
          resendCount: nextResendCount,
        },
        transaction,
      });
      throw new AppError(
        "Nombre maximal de renvois atteint. Reessayez plus tard.",
        429,
      );
    }

    const code = generateOtpCode();
    await otp.update(
      {
        code,
        expiresAt: computeExpiryDate(),
        resendCount: nextResendCount,
        lastSentAt: new Date(),
      },
      { transaction },
    );

    await writeAuditLog({
      action: 'auth.otp.resent',
      entityType: 'auth_otp',
      entityId: otp.id,
      status: 'success',
      ipAddress: authContext.ipAddress,
      userAgent: authContext.userAgent,
      metadata: {
        phoneNumber: normalizedPhone,
        purpose,
        resendCount: nextResendCount,
      },
      transaction,
    });

    return {
      otpId: otp.id,
      phoneNumber: displayPhone(normalizedPhone),
      normalizedPhoneNumber: normalizedPhone,
      expiresAt: otp.expiresAt,
      debugOtpCode: code,
    };
  });
}

async function verifyOtp(
  { phoneNumber, code, firstName, lastName, birthDate, pinCode },
  context,
) {
  const { normalizedPhone } = validateAndNormalizePhone(phoneNumber);
  const normalizedCode = String(code || '').replace(/\D/g, '').trim();
  const authContext = buildAuthContext(context);
  if (!/^\d{4}$/.test(normalizedCode)) {
    throw new AppError('Le code OTP doit contenir 4 chiffres.', 422);
  }

  const otp = await getLatestOtpForVerification(normalizedPhone);

  if (!otp) {
    await writeAuditLog({
      action: 'auth.otp.verify_failed',
      entityType: 'auth_otp',
      status: 'failed',
      ipAddress: authContext.ipAddress,
      userAgent: authContext.userAgent,
      metadata: {
        phoneNumber: normalizedPhone,
        reason: 'otp_not_found',
      },
    });
    throw new AppError('Code OTP invalide ou expire.', 422);
  }

  if (otp.blockedUntil && new Date(otp.blockedUntil).getTime() > Date.now()) {
    throw new AppError(
      "Trop de tentatives. Reessayez plus tard avant de verifier un nouveau code.",
      429,
    );
  }

  if (new Date(otp.expiresAt).getTime() <= Date.now()) {
    await writeAuditLog({
      action: 'auth.otp.verify_failed',
      entityType: 'auth_otp',
      entityId: otp.id,
      status: 'failed',
      ipAddress: authContext.ipAddress,
      userAgent: authContext.userAgent,
      metadata: {
        phoneNumber: normalizedPhone,
        reason: 'otp_expired',
      },
    });
    throw new AppError('Code OTP invalide ou expire.', 422);
  }

  if (otp.code !== normalizedCode) {
    const nextAttemptCount = Number(otp.attemptCount) + 1;
    const updates = { attemptCount: nextAttemptCount };
    let status = 'failed';

    if (nextAttemptCount >= env.otpMaxAttempts) {
      updates.blockedUntil = computeBlockDate();
      status = 'blocked';
    }

    await otp.update(updates);
    await writeAuditLog({
      action: 'auth.otp.verify_failed',
      entityType: 'auth_otp',
      entityId: otp.id,
      status,
      ipAddress: authContext.ipAddress,
      userAgent: authContext.userAgent,
      metadata: {
        phoneNumber: normalizedPhone,
        reason: 'invalid_code',
        attemptCount: nextAttemptCount,
      },
    });

    if (nextAttemptCount >= env.otpMaxAttempts) {
      throw new AppError(
        "Nombre maximal d'essais atteint. Reessayez plus tard avec un nouveau code.",
        429,
      );
    }

    throw new AppError('Code OTP invalide ou expire.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    let user = await models.User.findOne({
      where: { phoneNumber: normalizedPhone },
      transaction,
    });

    assertUserIsActive(user);

    if (!user && otp.purpose === 'login') {
      throw new AppError('Aucun compte trouve pour ce numero.', 404);
    }

    if (!user) {
      const normalizedFirstName = normalizePersonalName(firstName);
      const normalizedLastName = normalizePersonalName(lastName);

      if (!isValidPersonalName(normalizedFirstName)) {
        throw new AppError('Le prenom est invalide.', 422);
      }
      if (!isValidPersonalName(normalizedLastName)) {
        throw new AppError('Le nom est invalide.', 422);
      }

      user = await models.User.create(
        {
          phoneNumber: normalizedPhone,
          displayName:
            buildDisplayNameFromIdentity(normalizedFirstName, normalizedLastName) ||
            'Utilisateur maTontine',
          firstName: normalizedFirstName,
          lastName: normalizedLastName,
          birthDate: normalizeBirthDate(birthDate),
          accountType: 'Personnel',
        },
        { transaction },
      );
    }

    await user.update(
      {
        lastLoginAt: new Date(),
      },
      { transaction },
    );

    await models.UserPreference.findOrCreate({
      where: { userId: user.id },
      defaults: { userId: user.id },
      transaction,
    });

    const preferences = await models.UserPreference.findOne({
      where: { userId: user.id },
      transaction,
    });

    if (
      preferences &&
      !preferences.pinCode &&
      isValidPinCode(pinCode)
    ) {
      await preferences.update(
        {
          pinEnabled: true,
          pinCode: hashClientPin(pinCode),
        },
        { transaction },
      );
    }

    await models.Wallet.findOrCreate({
      where: { userId: user.id },
      defaults: { userId: user.id },
      transaction,
    });

    await otp.update(
      {
        consumedAt: new Date(),
        attemptCount: 0,
        blockedUntil: null,
      },
      { transaction },
    );

    await writeAuditLog({
      userId: user.id,
      action: 'auth.login_success',
      entityType: 'user',
      entityId: user.id,
      status: 'success',
      ipAddress: authContext.ipAddress,
      userAgent: authContext.userAgent,
      metadata: {
        phoneNumber: normalizedPhone,
        purpose: otp.purpose,
      },
      transaction,
    });

    return {
      token: signToken(user),
      user: {
        id: user.id,
        phoneNumber: displayPhone(user.phoneNumber),
        displayName: user.displayName,
        firstName: user.firstName,
        lastName: user.lastName,
        birthDate: user.birthDate,
        accountType: user.accountType,
        memberSince: user.memberSince,
        lastLoginAt: user.lastLoginAt,
        preferences: sanitizePreferences(preferences),
      },
    };
  });
}

async function getCurrentUserProfile(userId) {
  const user = await models.User.findByPk(userId, {
    include: [
      { model: models.UserPreference, as: 'preferences' },
      { model: models.Wallet, as: 'wallet' },
    ],
  });

  if (!user) {
    throw new AppError('Utilisateur introuvable.', 404);
  }

  return {
    id: user.id,
    phoneNumber: displayPhone(user.phoneNumber),
    displayName: user.displayName,
    firstName: user.firstName,
    lastName: user.lastName,
    birthDate: user.birthDate,
    accountType: user.accountType,
    memberSince: user.memberSince,
    lastLoginAt: user.lastLoginAt,
    preferences: sanitizePreferences(user.preferences),
    wallet: user.wallet,
  };
}

module.exports = {
  validateAndNormalizePhone,
  normalizePhone,
  displayPhone,
  normalizeDisplayName,
  isValidDisplayName,
  normalizePersonalName,
  isValidPersonalName,
  hashClientPin,
  isValidPinCode,
  requestOtp,
  resendOtp,
  verifyOtp,
  getCurrentUserProfile,
};
