const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./admin-auth.service');

async function login(req, res) {
  const data = await service.login(req.body, getRequestContext(req));
  return ok(res, data, 'Connexion admin reussie.');
}

module.exports = {
  login,
};
