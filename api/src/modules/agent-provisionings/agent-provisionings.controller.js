const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-provisionings.service');

async function list(req, res) {
  const data = await service.listProvisionings(req.agentProfile.id);
  return ok(res, data, 'Provisionings charges.');
}

async function create(req, res) {
  const data = await service.createProvisioning(
    req.agentProfile,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Provisioning enregistre.', 201);
}

async function reverse(req, res) {
  const data = await service.reverseProvisioning(
    req.agentProfile,
    req.params.provisioningId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Provisioning corrige.');
}

module.exports = { list, create, reverse };
