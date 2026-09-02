const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./goal-templates.service');

// --- Cote client (mobile) ---

async function listTemplates(req, res) {
  const data = await service.listActiveTemplates(req.auth.userId);
  return ok(res, data, 'Coffres par defaut charges.');
}

async function applyTemplates(req, res) {
  const data = await service.applyTemplates(
    req.auth.userId,
    req.body?.templateIds,
    getRequestContext(req),
  );
  return ok(res, data, 'Vos coffres de demarrage sont prets.', 201);
}

// --- Cote administration ---

async function adminList(req, res) {
  const data = await service.listAllTemplates();
  return ok(res, data, 'Coffres par defaut charges.');
}

async function adminCreate(req, res) {
  const adminId = req.auth?.adminId ?? req.auth?.userId ?? null;
  const data = await service.createTemplate(
    req.body,
    adminId,
    getRequestContext(req),
  );
  return ok(res, data, 'Coffre par defaut cree.', 201);
}

async function adminUpdate(req, res) {
  const adminId = req.auth?.adminId ?? req.auth?.userId ?? null;
  const data = await service.updateTemplate(
    req.params.id,
    req.body,
    adminId,
    getRequestContext(req),
  );
  return ok(res, data, 'Coffre par defaut mis a jour.');
}

async function adminDelete(req, res) {
  const adminId = req.auth?.adminId ?? req.auth?.userId ?? null;
  const data = await service.deleteTemplate(
    req.params.id,
    adminId,
    getRequestContext(req),
  );
  return ok(res, data, 'Coffre par defaut supprime.');
}

module.exports = {
  listTemplates,
  applyTemplates,
  adminList,
  adminCreate,
  adminUpdate,
  adminDelete,
};
