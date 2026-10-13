// Point d'entrée Serverless pour Vercel.
// NB : ne pas nommer ce fichier `vercel.js` à la racine — Vercel réserve ce nom
// (comme `vercel.ts`) au fichier de configuration du projet.
// Pas d'app.listen() ici : Vercel invoque directement le handler exporté.
const app = require('../src/app');
const { sequelize } = require('../src/database/models');

let dbReady = null;

module.exports = async (req, res) => {
  // Authentification BDD une seule fois par instance (réutilisée entre requêtes à chaud).
  if (!dbReady) {
    dbReady = sequelize.authenticate().catch((error) => {
      dbReady = null;
      console.error('Erreur DB Vercel:', error);
    });
  }
  await dbReady;

  return app(req, res);
};
