const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const { listAppVersions, updateAppVersion } = require('./app-version.service');

/** GET /api/v1/admin/app-versions */
async function list(req, res) {
  const data = await listAppVersions();
  return ok(res, data, 'Versions des applications chargees avec succes.');
}

/** PUT /api/v1/admin/app-versions/:app */
async function update(req, res) {
  const data = await updateAppVersion(req.params.app, req.body, {
    ...getRequestContext(req),
    adminUsername: req.admin?.username || null,
  });
  return ok(res, data, 'Version publiee avec succes.');
}

module.exports = { list, update };
