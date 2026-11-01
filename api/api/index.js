// Point d'entrée Serverless pour Vercel.
// NB : ne pas nommer ce fichier `vercel.js` à la racine — Vercel réserve ce nom
// (comme `vercel.ts`) au fichier de configuration du projet.
// Pas d'app.listen() ici : Vercel invoque directement le handler exporté.
const app = require('../src/app');
const { sequelize } = require('../src/database/models');

let isConnected = false;

module.exports = async (req, res) => {
  if (!isConnected) {
    try {
      // Timeout strict de 6s pour l'authentification initiale lors d'un cold start
      await Promise.race([
        sequelize.authenticate(),
        new Promise((_, reject) =>
          setTimeout(
            () => reject(new Error('Timeout de connexion BDD (6s) lors du cold start')),
            6000,
          ),
        ),
      ]);
      isConnected = true;
    } catch (error) {
      console.error('Erreur DB Vercel (Cold Start):', error.message || error);
      isConnected = false;
      return res.status(503).json({
        success: false,
        message: 'Base de données momentanément indisponible, veuillez réessayer dans quelques instants.',
      });
    }
  }

  return app(req, res);
};
