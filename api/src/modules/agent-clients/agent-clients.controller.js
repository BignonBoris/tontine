const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-clients.service');

async function search(req, res) {
  const data = await service.searchClients(req.query.q, req.query.type);
  return ok(res, data, 'Clients charges.');
}

async function listMine(req, res) {
  const data = await service.listMyClients(
    req.agentProfile.id,
    req.query.q,
    req.query.filter,
  );
  return ok(res, data, 'Portefeuille client charge.');
}

async function detailMine(req, res) {
  const data = await service.getMyClientDetail(
    req.agentProfile.id,
    req.params.clientId,
  );
  return ok(res, data, 'Fiche client chargee.');
}

async function create(req, res) {
  const data = await service.createClient(
    req.agentProfile,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Client cree avec succes.', 201);
}

async function startTontine(req, res) {
  const data = await service.startClientTontine(
    req.agentProfile,
    req.params.clientId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Tontine demarree avec succes.');
}

async function uploadKyc(req, res) {
  const data = await service.uploadClientKyc(
    req.agentProfile,
    req.params.clientId,
    req.body,
    req.files,
    getRequestContext(req),
  );
  return ok(res, data, 'Dossier KYC du client televerse avec succes.', 201);
}

async function updatePhone(req, res) {
  const data = await service.updatePhone(
    req.agentProfile,
    req.params.clientId,
    req.body,
    getRequestContext(req)
  );
  return ok(res, data, 'Numero de telephone mis a jour.');
}

module.exports = { search, listMine, detailMine, create, startTontine, uploadKyc, updatePhone };
