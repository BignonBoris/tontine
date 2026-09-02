const admin = require('../../config/firebase');
const { models } = require('../../database/models');

function toText(value, fallback = '') {
  if (value === null || value === undefined) {
    return fallback;
  }
  const normalized = String(value).trim();
  return normalized.length > 0 ? normalized : fallback;
}

function toIsoString(value) {
  if (!value) {
    return '';
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '';
  }
  return date.toISOString();
}

function buildPushPayload(notification, tokens) {
  const title = toText(notification?.title, 'Notification');
  const body = toText(notification?.message, '');

  return {
    notification: {
      title,
      body,
    },
    data: {
      notificationId: toText(notification?.id),
      userId: toText(notification?.userId),
      type: toText(notification?.type, 'system'),
      title,
      message: body,
      createdAtClient: toIsoString(notification?.createdAtClient),
      route: '/notifications',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    tokens,
  };
}

async function sendPushNotificationToUser(notification) {
  if (!notification?.userId) {
    return { skipped: true };
  }

  // Use dynamic import to avoid circular dependency issues if any
  const { models } = require('../../database/models');
  
  const pushDevices = await models.PushDeviceToken.findAll({
    where: {
      userId: notification.userId,
      isActive: true,
    },
    order: [['updatedAt', 'DESC']],
  });

  const registrationIds = pushDevices
    .map((token) => token.token)
    .filter((token) => toText(token).length > 0);

  if (registrationIds.length === 0) {
    return { skipped: true, reason: 'no_tokens' };
  }

  const payload = buildPushPayload(notification, registrationIds);

  try {
    const response = await admin.messaging().sendEachForMulticast(payload);
    
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error?.code || 'unknown';
          // Check for tokens that are no longer valid
          if (
            error === 'messaging/invalid-registration-token' ||
            error === 'messaging/registration-token-not-registered'
          ) {
            invalidTokens.push(registrationIds[idx]);
          } else {
            console.warn(`Push failed for token ${registrationIds[idx]}: ${error}`);
          }
        }
      });

      if (invalidTokens.length > 0) {
        await models.PushDeviceToken.update(
          {
            isActive: false,
            lastSeenAt: new Date(),
          },
          {
            where: {
              token: invalidTokens,
            },
          }
        );
      }
    }

    return {
      skipped: false,
      sent: registrationIds.length - response.failureCount,
      failed: response.failureCount,
    };
  } catch (error) {
    console.error(`Echec de diffusion push via firebase-admin pour la notification ${notification.id || 'unknown'}:`, error);
    return { skipped: false, sent: 0, error: error.message };
  }
}

module.exports = { sendPushNotificationToUser };
