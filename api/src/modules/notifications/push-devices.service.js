const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models } = require('../../database/models');

function normalizeString(value, fallback = '') {
  if (value === null || value === undefined) {
    return fallback;
  }

  const normalized = String(value).trim();
  return normalized.length > 0 ? normalized : fallback;
}

function normalizePlatform(value) {
  const normalized = normalizeString(value, 'unknown').toLowerCase();
  if (['android', 'ios', 'web'].includes(normalized)) {
    return normalized;
  }
  return normalized.slice(0, 32) || 'unknown';
}

function normalizeAppName(value) {
  const normalized = normalizeString(value, 'mobile').toLowerCase();
  return normalized.slice(0, 32) || 'mobile';
}

function formatPushDeviceToken(record) {
  if (!record) {
    return null;
  }

  const plain = typeof record.get === 'function'
    ? record.get({ plain: true })
    : record;

  return {
    id: plain.id || null,
    userId: plain.userId || null,
    platform: plain.platform || 'unknown',
    appName: plain.appName || 'mobile',
    deviceId: plain.deviceId || null,
    isActive: Boolean(plain.isActive),
    lastSeenAt: plain.lastSeenAt || null,
    createdAt: plain.createdAt || null,
    updatedAt: plain.updatedAt || null,
  };
}

async function registerPushDevice(userId, payload = {}, requestContext = {}) {
  const token = normalizeString(payload.token || payload.fcmToken);
  if (!token) {
    throw new AppError('Le token push est requis.', 400);
  }

  const platform = normalizePlatform(payload.platform);
  const appName = normalizeAppName(payload.appName);
  const deviceId = normalizeString(payload.deviceId, null);
  const now = new Date();

  const existing = await models.PushDeviceToken.findOne({
    where: { token },
  });

  let record;
  const changedFields = {
    userId,
    token,
    platform,
    appName,
    deviceId,
    isActive: true,
    lastSeenAt: now,
  };

  if (existing) {
    record = await existing.update(changedFields);
  } else {
    record = await models.PushDeviceToken.create(changedFields);
  }

  await writeAuditLog({
    userId,
    action: existing ? 'notification.pushDevice.updated' : 'notification.pushDevice.registered',
    entityType: 'push_device_token',
    entityId: record.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      platform,
      appName,
      deviceId,
    },
  });

  return formatPushDeviceToken(record);
}

async function unregisterPushDevice(userId, payload = {}, requestContext = {}) {
  const token = normalizeString(payload.token || payload.fcmToken);
  if (!token) {
    throw new AppError('Le token push est requis.', 400);
  }

  const record = await models.PushDeviceToken.findOne({
    where: {
      token,
      userId,
    },
  });

  if (!record) {
    return null;
  }

  await record.update({
    isActive: false,
    lastSeenAt: new Date(),
  });

  await writeAuditLog({
    userId,
    action: 'notification.pushDevice.unregistered',
    entityType: 'push_device_token',
    entityId: record.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      platform: record.platform,
      appName: record.appName,
      deviceId: record.deviceId,
    },
  });

  return formatPushDeviceToken(record);
}

module.exports = {
  registerPushDevice,
  unregisterPushDevice,
};
