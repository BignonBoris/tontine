const jwt = require('jsonwebtoken');
const { Op } = require('sequelize');
const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

function normalizePhone(phoneNumber) {
  const digits = String(phoneNumber || '').replace(/\D/g, '');
  return digits.length > 8 ? digits.slice(-8) : digits;
}

function displayPhone(phoneNumber) {
  if (phoneNumber.length !== 8) {
    return `+229 ${phoneNumber}`;
  }
  return `+229 ${phoneNumber.slice(0, 2)} ${phoneNumber.slice(
    2,
    4,
  )} ${phoneNumber.slice(4, 6)} ${phoneNumber.slice(6, 8)}`;
}

function generateOtpCode() {
  return `${1000 + Math.floor(Math.random() * 9000)}`;
}

function signToken(user) {
  return jwt.sign({ sub: user.id, phoneNumber: user.phoneNumber }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn,
  });
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

  return {
    otpId: otp.id,
    phoneNumber: displayPhone(normalizedPhone),
    normalizedPhoneNumber: normalizedPhone,
    expiresAt: otp.expiresAt,
    debugOtpCode: code,
  };
}

async function requestOtp(payload, context) {
  const { phoneNumber, purpose } = payload;
  const normalizedPhone = normalizePhone(phoneNumber);
  const authContext = buildAuthContext(context);

  if (normalizedPhone.length !== 8) {
    throw new AppError('Le numero doit contenir 8 chiffres.', 422);
  }

  await assertPhonePurposeConsistency(normalizedPhone, purpose);

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
  const normalizedPhone = normalizePhone(phoneNumber);
  const authContext = buildAuthContext(context);

  if (normalizedPhone.length !== 8) {
    throw new AppError('Le numero doit contenir 8 chiffres.', 422);
  }

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

async function verifyOtp({ phoneNumber, code }, context) {
  const normalizedPhone = normalizePhone(phoneNumber);
  const authContext = buildAuthContext(context);
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

  if (otp.code !== code) {
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

    if (!user && otp.purpose === 'login') {
      throw new AppError('Aucun compte trouve pour ce numero.', 404);
    }

    if (!user) {
      user = await models.User.create(
        {
          phoneNumber: normalizedPhone,
          displayName: 'Utilisateur maTontine',
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
        accountType: user.accountType,
        memberSince: user.memberSince,
        lastLoginAt: user.lastLoginAt,
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
    accountType: user.accountType,
    memberSince: user.memberSince,
    lastLoginAt: user.lastLoginAt,
    preferences: user.preferences,
    wallet: user.wallet,
  };
}

module.exports = {
  normalizePhone,
  displayPhone,
  requestOtp,
  resendOtp,
  verifyOtp,
  getCurrentUserProfile,
};
