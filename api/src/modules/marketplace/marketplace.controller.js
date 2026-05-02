const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./marketplace.service');

async function listOffers(req, res) {
  const data = await service.listOffers(req.query);
  return ok(res, data, 'Articles charges.');
}

async function listFavorites(req, res) {
  const data = await service.listFavorites(req.auth.userId);
  return ok(res, data, 'Favoris charges.');
}

async function toggleFavorite(req, res) {
  const data = await service.toggleFavorite(req.auth.userId, req.params.offerId);
  return ok(res, data, 'Favori mis a jour.');
}

async function listOrders(req, res) {
  const data = await service.listOrders(req.auth.userId);
  return ok(res, data, 'Commandes chargees.');
}

async function createOrder(req, res) {
  const data = await service.createOrder(
    req.auth.userId,
    req.body.offerId,
    Number(req.body.quantity || 1),
    getRequestContext(req),
  );
  return ok(res, data, 'Commande creee.', 201);
}

async function advanceOrder(req, res) {
  const data = await service.advanceOrder(
    req.auth.userId,
    req.params.orderId,
    getRequestContext(req),
  );
  return ok(res, data, 'Commande mise a jour.');
}

async function cancelOrder(req, res) {
  const data = await service.cancelOrder(
    req.auth.userId,
    req.params.orderId,
    getRequestContext(req),
  );
  return ok(res, data, 'Commande annulee.');
}

module.exports = {
  listOffers,
  listFavorites,
  toggleFavorite,
  listOrders,
  createOrder,
  advanceOrder,
  cancelOrder,
};
