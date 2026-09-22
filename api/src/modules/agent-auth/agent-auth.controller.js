const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-auth.service');

async function login(req, res) {
  const { phoneNumber, pin, deviceId } = req.body;
  const data = await service.loginAgent(
    { phoneNumber, pin, deviceId },
    getRequestContext(req),
  );
  return ok(res, data, 'Connexion agent reussie.');
}

module.exports = { login };
