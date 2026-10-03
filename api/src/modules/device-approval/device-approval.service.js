const env = require('../../config/env');
const AppError = require('../../common/errors/app-error');
const { models } = require('../../database/models');

function assertEnabled() {
  if (!env.deviceApprovalEnabled) throw new AppError('Autorisation multi-appareil désactivée.', 404);
}
function deviceId(value) {
  const result = String(value || '').trim();
  if (!result || result.length > 128) throw new AppError('Identifiant appareil invalide.', 422);
  return result;
}
async function createRequest({ userId, requestingDeviceId, currentSessionId, transaction }) {
  assertEnabled();
  const expiresAt = new Date(Date.now() + env.deviceApprovalTtlSeconds * 1000);
  await models.DeviceApprovalRequest.update({ status: 'expired', respondedAt: new Date() }, { where: { userId, status: 'pending' }, transaction });
  return models.DeviceApprovalRequest.create({ userId, requestingDeviceId: deviceId(requestingDeviceId), currentSessionId: currentSessionId || null, expiresAt }, { transaction });
}
async function getRequest(requestId, userId) {
  assertEnabled();
  const request = await models.DeviceApprovalRequest.findOne({ where: { id: requestId, userId } });
  if (!request) throw new AppError('Demande de connexion introuvable.', 404);
  if (request.status === 'pending' && request.expiresAt <= new Date()) await request.update({ status: 'expired', respondedAt: new Date() });
  return request.reload();
}
async function getRequestStatus(requestId, requestingDeviceId) {
  assertEnabled();
  const request = await models.DeviceApprovalRequest.findOne({
    where: { id: requestId, requestingDeviceId: deviceId(requestingDeviceId) },
  });
  if (!request) throw new AppError('Demande de connexion introuvable.', 404);
  if (request.status === 'pending' && request.expiresAt <= new Date()) {
    await request.update({ status: 'expired', respondedAt: new Date() });
  }
  return request.reload();
}
async function listPending(userId) {
  assertEnabled();
  await models.DeviceApprovalRequest.update(
    { status: 'expired', respondedAt: new Date() },
    { where: { userId, status: 'pending', expiresAt: { [require('sequelize').Op.lt]: new Date() } } },
  );
  return models.DeviceApprovalRequest.findAll({
    where: { userId, status: 'pending' },
    order: [['createdAt', 'DESC']],
  });
}
async function decideRequest({ requestId, userId, approved, deviceId: approverDeviceId }) {
  const request = await getRequest(requestId, userId);
  if (request.status !== 'pending') throw new AppError('Cette demande de connexion n’est plus active.', 409);
  await request.update({ status: approved ? 'approved' : 'rejected', respondedAt: new Date(), approvedByDeviceId: approved ? deviceId(approverDeviceId) : null });
  return request.reload();
}
module.exports = {
  createRequest,
  getRequest,
  getRequestStatus,
  listPending,
  decideRequest,
};
