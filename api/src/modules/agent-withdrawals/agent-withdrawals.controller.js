const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('../withdrawals/withdrawals.service');

async function searchByReference(req, res) {
  const data = await service.findPendingWithdrawalByReference(
    req.query.reference,
  );
  return ok(res, data, 'Retrait trouve.');
}

async function pay(req, res) {
  const data = await service.payWithdrawal(
    req.agentProfile,
    req.params.withdrawalId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Retrait paye.');
}

async function preview(req, res) {
  const data = await service.previewDirectWithdrawal(
    req.agentProfile,
    req.body,
  );
  return ok(res, data, 'Client valide.');
}

async function create(req, res) {
  const data = await service.createDirectWithdrawal(
    req.agentProfile,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Retrait cree.', 201);
}

module.exports = { searchByReference, pay, preview, create };
