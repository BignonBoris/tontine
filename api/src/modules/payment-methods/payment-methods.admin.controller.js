const { ok } = require('../../common/utils/api-response');
const service = require('./payment-methods.service');

async function list(req, res) {
  const data = await service.listPaymentMethods({
    operation: req.query.operation,
    includeDisabled: true,
  });
  return ok(res, data, 'Moyens de paiement charges.');
}

async function toggle(req, res) {
  const data = await service.togglePaymentMethod(
    req.params.methodId,
    req.body,
    {
      ipAddress: req.ip || null,
      userAgent: req.get('user-agent') || null,
      adminUsername: req.admin?.username || null,
    },
  );
  return ok(res, data, 'Moyen de paiement mis a jour.');
}

module.exports = {
  list,
  toggle,
};
