const { ok } = require('../../common/utils/api-response');
const service = require('./agent-dashboard.service');

async function overview(req, res) {
  const data = await service.getOverview(req.agentProfile.id);
  return ok(res, data, 'Vue agent chargee.');
}

module.exports = { overview };
