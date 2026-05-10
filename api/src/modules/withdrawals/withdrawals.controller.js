const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./withdrawals.service');

async function list(req, res) {
  const data = await service.listClientWithdrawals(req.auth.userId);
  return ok(res, data, 'Retraits charges.');
}

async function create(req, res) {
  const data = await service.createWithdrawal(
    req.auth.userId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Retrait demande.', 201);
}

async function cancel(req, res) {
  const data = await service.cancelWithdrawal(
    req.auth.userId,
    req.params.withdrawalId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Retrait annule.');
}

async function regenerateCode(req, res) {
  const data = await service.regenerateWithdrawalCode(
    req.auth.userId,
    req.params.withdrawalId,
    getRequestContext(req),
  );
  return ok(res, data, 'Nouveau code genere.');
}

module.exports = { list, create, cancel, regenerateCode };
