const { DataTypes } = require('sequelize');

async function ensureMarketOfferCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();

  try {
    const columns = await queryInterface.describeTable('market_offers');

    if (!columns.description_html) {
      await queryInterface.addColumn('market_offers', 'description_html', {
        type: DataTypes.TEXT,
        allowNull: true,
      });
    }
  } catch (_) {
    // Table inexistante: rien a faire ici, sequelize sync gerera la creation.
  }
}

module.exports = {
  ensureMarketOfferCompatibility,
};
