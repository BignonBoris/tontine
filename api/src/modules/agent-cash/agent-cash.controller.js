const { ok } = require('../../common/utils/api-response');
const service = require('./agent-cash.service');

async function overview(req, res) {
  const data = await service.getCashOverview(req.agentProfile.id);
  return ok(res, data, 'Caisse agent chargee.');
}

module.exports = { overview };
