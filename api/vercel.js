const app = require('./src/app');
const { sequelize } = require('./src/database/models');

// Vercel Serverless Functions n'ont pas besoin de app.listen().
// On tente la connexion à la BDD avant de traiter la requête si nécessaire, 
// mais Sequelize le fait souvent automatiquement au premier query.
// On exporte simplement l'application Express pour que Vercel puisse l'utiliser.

module.exports = async (req, res) => {
  // Petite sécurité pour s'assurer que Sequelize est prêt
  try {
    await sequelize.authenticate();
  } catch (error) {
    console.error('Erreur DB Vercel:', error);
  }
  
  return app(req, res);
};
