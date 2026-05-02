const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./marketplace.controller');

const router = express.Router();

/**
 * @swagger
 * /marketplace/offers:
 *   get:
 *     tags: [Marketplace]
 *     summary: Lister les articles marketplace
 *     parameters:
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *       - in: query
 *         name: category
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Liste d'articles
 */
router.get('/offers', asyncHandler(controller.listOffers));
router.get('/favorites', authenticate, asyncHandler(controller.listFavorites));
router.post(
  '/favorites/:offerId/toggle',
  authenticate,
  asyncHandler(controller.toggleFavorite),
);
router.get('/orders', authenticate, asyncHandler(controller.listOrders));
router.post('/orders', authenticate, asyncHandler(controller.createOrder));
router.post(
  '/orders/:orderId/advance',
  authenticate,
  asyncHandler(controller.advanceOrder),
);
router.post(
  '/orders/:orderId/cancel',
  authenticate,
  asyncHandler(controller.cancelOrder),
);

module.exports = router;
