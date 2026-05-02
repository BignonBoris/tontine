const { models } = require('../../database/models');

async function writeAuditLog({
  userId = null,
  action,
  entityType,
  entityId = null,
  status = 'success',
  ipAddress = null,
  userAgent = null,
  metadata = null,
  transaction = null,
}) {
  return models.AuditLog.create({
    userId,
    action,
    entityType,
    entityId,
    status,
    ipAddress,
    userAgent,
    metadata,
  }, transaction ? { transaction } : undefined);
}

module.exports = { writeAuditLog };
