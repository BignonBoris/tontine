const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./admin-auth.service');

async function login(req, res) {
  const data = await service.login(req.body, getRequestContext(req));
  return ok(res, data, 'Session admin ouverte.');
}

async function session(req, res) {
  const data = service.getSession(req.admin);
  return ok(res, data, 'Session admin chargee.');
}

module.exports = {
  login,
  session,
};
