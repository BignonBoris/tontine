const { ok } = require('../../common/utils/api-response');
const service = require('./dashboard.service');

async function getSummary(req, res) {
  const data = await service.getSummary(req.auth.userId);
  return ok(res, data, 'Dashboard charge.');
}

module.exports = { getSummary };
