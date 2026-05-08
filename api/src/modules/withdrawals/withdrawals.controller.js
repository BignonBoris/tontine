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
  return ok(res, data, 'Retrait demande.');
}

async function cancel(req, res) {
  const data = await service.cancelWithdrawal(
    req.auth.userId,
    req.params.withdrawalId,
    getRequestContext(req),
  );
  return ok(res, data, 'Retrait annule.');
}

async function search(req, res) {
  const data = await service.searchPendingWithdrawalByReference(
    req.query.reference,
  );
  return ok(res, data, 'Retrait trouve.');
}

async function pay(req, res) {
  const data = await service.payWithdrawal(
    req.agentProfile,
    req.params.withdrawalId,
    getRequestContext(req),
  );
  return ok(res, data, 'Retrait paye.');
}

module.exports = { list, create, cancel, search, pay };
