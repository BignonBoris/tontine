const marketOffersSeed = require('./market-offers.seed');

async function runSeeds(models) {
  const { MarketOffer } = models;
  await Promise.all(
    marketOffersSeed.map((offer) =>
      MarketOffer.upsert({
        ...offer,
        isActive: true,
      }),
    ),
  );
}

module.exports = runSeeds;
