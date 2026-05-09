const { ok } = require('../../common/utils/api-response');
const service = require('./admin-commissions.service');

async function overview(req, res) {
  const data = await service.getOverview(req.query);
  return ok(res, data, 'Vue commissions admin chargee.');
}

async function agentDetail(req, res) {
  const data = await service.getAgentDetail(req.params.agentId, req.query);
  return ok(res, data, 'Detail agent charge.');
}

module.exports = {
  overview,
  agentDetail,
};
