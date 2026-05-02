const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./profile.service');

async function getProfile(req, res) {
  const data = await service.getProfile(req.auth.userId);
  return ok(res, data, 'Profil charge.');
}

async function updateProfile(req, res) {
  const data = await service.updateProfile(
    req.auth.userId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Profil mis a jour.');
}

async function updatePreferences(req, res) {
  const data = await service.updatePreferences(
    req.auth.userId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Preferences mises a jour.');
}

module.exports = { getProfile, updateProfile, updatePreferences };
