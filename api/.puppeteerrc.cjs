const { join } = require('path');

/**
 * Configuration Puppeteer pour Render et les environnements de déploiement cloud.
 * Force le téléchargement et la recherche du binaire Chromium dans le répertoire du projet
 * (.cache/puppeteer) afin que Render le conserve entre l'étape de build et le conteneur runtime.
 *
 * @type {import("puppeteer").Configuration}
 */
module.exports = {
  cacheDirectory: join(__dirname, '.cache', 'puppeteer'),
};
