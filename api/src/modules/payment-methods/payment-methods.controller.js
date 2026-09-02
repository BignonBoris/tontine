const { ok } = require('../../common/utils/api-response');
const service = require('./payment-methods.service');

async function list(req, res) {
  const data = await service.listPaymentMethods({
    operation: req.query.operation,
  });
  return ok(res, data, 'Moyens de paiement charges.');
}

module.exports = { list };
