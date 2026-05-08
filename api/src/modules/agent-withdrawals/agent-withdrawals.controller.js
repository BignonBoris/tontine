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

module.exports = { searchByReference, pay };
