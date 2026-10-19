const { getAppVersion } = require('./app-version.service');

/**
 * GET /api/v1/app-version/:app        (app = agent | client)
 * GET /api/v1/agent/app-version       (alias historique = agent)
 * Endpoint public (non authentifié) — l'app peut le consulter avant/après login.
 */
async function getVersion(req, res) {
  const data = await getAppVersion(req.params.app || 'agent');
  // Pas de cache : une nouvelle version doit être visible immédiatement.
  res.set('Cache-Control', 'no-store');
  return res.status(200).json({
    success: true,
    data,
  });
}

module.exports = { getVersion };
