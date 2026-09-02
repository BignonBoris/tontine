const adminReconciliationService = require('./admin-reconciliation.service');
const asyncHandler = require('../../common/utils/async-handler');
const { ok } = require('../../common/utils/api-response');

const runReconciliation = asyncHandler(async (req, res) => {
  const report = await adminReconciliationService.runReconciliation();

  return ok(res, report, 'Rapport de réconciliation généré avec succès');
});

module.exports = {
  runReconciliation,
};
