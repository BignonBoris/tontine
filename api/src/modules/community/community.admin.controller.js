const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./community.service');

function adminContext(req) {
  return { ...getRequestContext(req), adminUsername: req.admin?.username || null };
}

/** GET /api/v1/admin/community/options */
async function options(req, res) {
  return ok(res, service.getOptions(), 'Options chargees.');
}

/** GET /api/v1/admin/community/brand-profile */
async function getBrandProfile(req, res) {
  return ok(res, await service.getBrandProfile(), 'Fiche de marque chargee.');
}

/** PUT /api/v1/admin/community/brand-profile */
async function updateBrandProfile(req, res) {
  const data = await service.updateBrandProfile(req.body, adminContext(req));
  return ok(res, data, 'Fiche de marque enregistree.');
}

/** POST /api/v1/admin/community/generate */
async function generate(req, res) {
  const data = await service.generatePosts(req.body, adminContext(req));
  return ok(res, data, `${data.length} brouillon(s) genere(s).`, 201);
}

/** POST /api/v1/admin/community/replies */
async function reply(req, res) {
  const data = await service.suggestReply(req.body, adminContext(req));
  return ok(res, data, 'Reponse proposee.', 201);
}

/** GET /api/v1/admin/community/posts */
async function list(req, res) {
  return ok(res, await service.listPosts(req.query), 'Brouillons charges.');
}

/** PATCH /api/v1/admin/community/posts/:id */
async function update(req, res) {
  const data = await service.updatePost(req.params.id, req.body, adminContext(req));
  return ok(res, data, 'Brouillon mis a jour.');
}

module.exports = { options, getBrandProfile, updateBrandProfile, generate, reply, list, update };
