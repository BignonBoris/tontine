const { models } = require('../../database/models');
const { writeAuditLog } = require('../../common/services/audit-log.service');

async function listNotifications(userId) {
  return models.Notification.findAll({
    where: { userId },
    order: [['createdAtClient', 'DESC']],
  });
}

async function markAsRead(userId, notificationId, requestContext = {}) {
  await models.Notification.update(
    { isRead: true },
    { where: { id: notificationId, userId } },
  );
  await writeAuditLog({
    userId,
    action: 'notification.read',
    entityType: 'notification',
    entityId: notificationId,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
  });
}

async function markAllAsRead(userId, requestContext = {}) {
  await models.Notification.update({ isRead: true }, { where: { userId } });
  await writeAuditLog({
    userId,
    action: 'notification.readAll',
    entityType: 'notification',
    entityId: userId,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
  });
}

module.exports = { listNotifications, markAsRead, markAllAsRead };
