const { ok } = require('../../common/utils/api-response');
const service = require('./agent-dashboard.service');
const commissionQueryService = require('../commission/commission-query.service');

async function overview(req, res) {
  const data = await service.getOverview(req.agentProfile.id);
  return ok(res, data, 'Vue agent chargee.');
}

async function commissions(req, res) {
  const data = await commissionQueryService.getAgentCommissionOverview(
    req.agentProfile.id,
    req.query,
  );
  return ok(res, data, 'Commissions agent chargees.');
}

module.exports = { overview, commissions };
