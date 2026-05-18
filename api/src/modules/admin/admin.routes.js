const express = require('express');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./admin.controller');

const router = express.Router();

router.use(authenticateAdmin);

router.get('/overview', asyncHandler(controller.overview));
router.get('/marketplace/overview', asyncHandler(controller.marketplaceOverview));
router.get('/marketplace/offers', asyncHandler(controller.marketplaceOffers));
router.post('/marketplace/offers', asyncHandler(controller.createMarketplaceOffer));
router.patch('/marketplace/offers/:offerId', asyncHandler(controller.updateMarketplaceOffer));
router.patch('/marketplace/offers/:offerId/status', asyncHandler(controller.updateMarketplaceOfferStatus));
router.get('/marketplace/orders', asyncHandler(controller.marketplaceOrders));
router.get('/marketplace/goals', asyncHandler(controller.marketplaceGoals));
router.get('/anomalies', asyncHandler(controller.anomalies));
router.get('/clients', asyncHandler(controller.clients));
router.get('/clients/:userId', asyncHandler(controller.clientDetail));
router.patch('/clients/:userId/status', asyncHandler(controller.updateClientStatus));
router.get('/agents', asyncHandler(controller.agents));
router.patch('/agents/:agentId/status', asyncHandler(controller.updateAgentStatus));
router.post('/agents/:agentId/top-up', asyncHandler(controller.topUpAgentCash));
router.get('/agents/:agentId/cash-history', asyncHandler(controller.agentCashHistory));
router.post(
  '/provisionings/:provisioningId/reverse',
  asyncHandler(controller.reverseProvisioning),
);
router.get('/withdrawals', asyncHandler(controller.withdrawals));
router.get('/withdrawals/:withdrawalId', asyncHandler(controller.withdrawalDetail));
router.get('/audit-logs', asyncHandler(controller.auditLogs));

module.exports = router;
