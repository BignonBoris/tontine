const { ok } = require('../../common/utils/api-response');
const service = require('./device-approval.service');

function deviceId(req) {
  return req.body?.deviceId || req.headers['x-device-id'];
}

async function getPending(req, res) {
  const requests = await service.listPending(req.auth.userId);
  return ok(res, requests, 'Demandes de connexion chargees.');
}

async function status(req, res) {
  const request = await service.getRequestStatus(
    req.params.requestId,
    req.query.deviceId || req.headers['x-device-id'],
  );
  return ok(res, request, 'Statut de connexion charge.');
}

async function approve(req, res) {
  const request = await service.decideRequest({
    requestId: req.params.requestId,
    userId: req.auth.userId,
    deviceId: deviceId(req),
    approved: true,
  });
  return ok(res, request, 'Connexion approuvee.');
}

async function reject(req, res) {
  const request = await service.decideRequest({
    requestId: req.params.requestId,
    userId: req.auth.userId,
    deviceId: deviceId(req),
    approved: false,
  });
  return ok(res, request, 'Connexion refusee.');
}

module.exports = { getPending, status, approve, reject };
