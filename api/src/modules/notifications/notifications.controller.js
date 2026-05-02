const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
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

module.exports = { listNotifications, markAsRead, markAllAsRead };
