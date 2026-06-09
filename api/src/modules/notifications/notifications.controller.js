const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const {
  subscribeNotificationCreated,
} = require('../../common/services/realtime-notification.service');
const pushDevicesService = require('./push-devices.service');
const service = require('./notifications.service');

async function listNotifications(req, res) {
  const data = await service.listNotifications(req.auth.userId);
  return ok(res, data, 'Notifications chargees.');
}

async function markAsRead(req, res) {
  await service.markAsRead(
    req.auth.userId,
    req.params.notificationId,
    getRequestContext(req),
  );
  return ok(res, null, 'Notification marquee comme lue.');
}

async function markAllAsRead(req, res) {
  await service.markAllAsRead(req.auth.userId, getRequestContext(req));
  return ok(res, null, 'Toutes les notifications sont lues.');
}

async function registerPushDevice(req, res) {
  const data = await pushDevicesService.registerPushDevice(
    req.auth.userId,
    req.body || {},
    getRequestContext(req),
  );
  return ok(res, data, 'Appareil enregistre pour les notifications.');
}

async function unregisterPushDevice(req, res) {
  const data = await pushDevicesService.unregisterPushDevice(
    req.auth.userId,
    req.body || {},
    getRequestContext(req),
  );
  return ok(res, data, 'Appareil desactive pour les notifications.');
}

function writeSseEvent(res, eventName, payload) {
  if (res.writableEnded || res.destroyed) {
    return;
  }

  res.write(`event: ${eventName}\n`);
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

async function streamNotifications(req, res) {
  const userId = req.auth.userId;

  res.status(200);
  res.set({
    'Content-Type': 'text/event-stream; charset=utf-8',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });

  if (typeof res.flushHeaders === 'function') {
    res.flushHeaders();
  }

  res.write(': connected\n\n');

  const heartbeat = setInterval(() => {
    if (res.writableEnded || res.destroyed) {
      return;
    }

    res.write(': heartbeat\n\n');
  }, 25000);

  const unsubscribe = subscribeNotificationCreated(userId, (notification) => {
    writeSseEvent(res, 'notification.created', notification);
  });

  let cleanedUp = false;
  const cleanup = () => {
    if (cleanedUp) {
      return;
    }

    cleanedUp = true;
    clearInterval(heartbeat);
    unsubscribe();
    if (!res.writableEnded) {
      res.end();
    }
  };

  req.on('close', cleanup);
  req.on('aborted', cleanup);
}

module.exports = {
  listNotifications,
  markAsRead,
  markAllAsRead,
  registerPushDevice,
  unregisterPushDevice,
  streamNotifications,
};
