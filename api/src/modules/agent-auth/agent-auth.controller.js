const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-auth.service');

async function login(req, res) {
  const data = await service.loginAgent(req.body, getRequestContext(req));
  return ok(res, data, 'Connexion agent reussie.');
}

module.exports = { login };
