const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-cash.service');

async function overview(req, res) {
  const data = await service.getCashOverview(req.agentProfile.id);
  return ok(res, data, 'Caisse agent chargee.');
}

async function topUp(req, res) {
  const data = await service.topUpCash(
    req.agentProfile,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Caisse agent approvisionnee.', 201);
}

module.exports = { overview, topUp };
