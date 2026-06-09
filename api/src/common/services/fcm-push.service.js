const https = require('node:https');
const { URL } = require('node:url');

const env = require('../../config/env');

const FCM_ENDPOINT = 'https://fcm.googleapis.com/fcm/send';
const MAX_BATCH_SIZE = 500;
const INVALID_TOKEN_ERRORS = new Set([
  'InvalidRegistration',
  'NotRegistered',
  'MismatchSenderId',
  'InvalidPackageName',
]);

function chunkArray(items, size) {
  const chunks = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

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

function requestJson(urlString, headers, body) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlString);
    const request = https.request(
      {
        method: 'POST',
        hostname: url.hostname,
        path: `${url.pathname}${url.search}`,
        headers: {
          ...headers,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (response) => {
        let responseBody = '';
        response.setEncoding('utf8');
        response.on('data', (chunk) => {
          responseBody += chunk;
        });
        response.on('end', () => {
          if (!responseBody) {
            resolve({ statusCode: response.statusCode, body: null });
            return;
          }

          try {
            resolve({
              statusCode: response.statusCode,
              body: JSON.parse(responseBody),
            });
          } catch (error) {
            reject(
              new Error(
                `Reponse FCM invalide (${response.statusCode}): ${responseBody}`,
              ),
            );
          }
        });
      },
    );

    request.on('error', reject);
    request.write(body);
    request.end();
  });
}

function buildPushPayload(notification) {
  const title = toText(notification?.title, 'Notification');
  const body = toText(notification?.message, '');

  return {
    title,
    body,
    data: {
      notificationId: toText(notification?.id),
      userId: toText(notification?.userId),
      type: toText(notification?.type, 'system'),
      title,
      message: body,
      createdAtClient: toIsoString(notification?.createdAtClient),
      route: '/notifications',
    },
  };
}

async function deactivateInvalidTokens(models, tokens) {
  if (!tokens.length) {
    return;
  }

  await models.PushDeviceToken.update(
    {
      isActive: false,
      lastSeenAt: new Date(),
    },
    {
      where: {
        token: tokens,
      },
    },
  );
}

async function sendBatch(models, batchTokens, notification) {
  if (!env.fcmServerKey) {
    return { skipped: true };
  }

  const pushPayload = buildPushPayload(notification);
  const response = await requestJson(
    FCM_ENDPOINT,
    {
      Authorization: `key=${env.fcmServerKey}`,
    },
    JSON.stringify({
      registration_ids: batchTokens,
      priority: 'high',
      notification: {
        title: pushPayload.title,
        body: pushPayload.body,
        sound: 'default',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      data: pushPayload.data,
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    const message =
      response.body && typeof response.body === 'object'
        ? JSON.stringify(response.body)
        : 'unknown';
    throw new Error(`Echec d'envoi FCM (${response.statusCode}): ${message}`);
  }

  const body = response.body || {};
  const results = Array.isArray(body.results) ? body.results : [];
  const invalidTokens = [];

  for (let index = 0; index < batchTokens.length; index += 1) {
    const result = results[index] || {};
    const error = toText(result.error);

    if (error && INVALID_TOKEN_ERRORS.has(error)) {
      invalidTokens.push(batchTokens[index]);
    }
  }

  if (invalidTokens.length > 0) {
    await deactivateInvalidTokens(models, invalidTokens);
  }

  return body;
}

async function sendPushNotificationToUser(notification) {
  if (!notification?.userId || !env.fcmServerKey) {
    return { skipped: true };
  }

  const { models } = require('../../database/models');
  const tokens = await models.PushDeviceToken.findAll({
    where: {
      userId: notification.userId,
      isActive: true,
    },
    order: [['updatedAt', 'DESC']],
  });

  const registrationIds = tokens
    .map((token) => token.token)
    .filter((token) => toText(token).length > 0);

  if (registrationIds.length === 0) {
    return { skipped: true, reason: 'no_tokens' };
  }

  const batches = chunkArray(registrationIds, MAX_BATCH_SIZE);
  const responses = [];

  for (const batch of batches) {
    try {
      const response = await sendBatch(models, batch, notification);
      responses.push(response);
    } catch (error) {
      console.error(
        `Echec de diffusion push pour la notification ${notification.id || 'unknown'}:`,
        error,
      );
    }
  }

  return {
    skipped: false,
    sent: registrationIds.length,
    batches: responses.length,
  };
}

module.exports = { sendPushNotificationToUser };
