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
router.get('/operations', asyncHandler(controller.operations));
router.get('/recouvrement', asyncHandler(controller.recovery));
router.post('/operations/withdrawals', asyncHandler(controller.recordWithdrawal));
router.post('/withdrawals/:withdrawalId/approve', asyncHandler(controller.approveWithdrawal));
router.post('/withdrawals/:withdrawalId/reject', asyncHandler(controller.rejectWithdrawal));
router.post('/withdrawals/:withdrawalId/paid', asyncHandler(controller.markWithdrawalPaid));
router.get('/clients', asyncHandler(controller.clients));
router.post('/clients', asyncHandler(controller.createClient));
router.get('/clients/:userId', asyncHandler(controller.clientDetail));
router.patch('/clients/:userId', asyncHandler(controller.updateClient));
router.post('/clients/:userId/start-tontine', asyncHandler(controller.startTontine));
router.post('/clients/:userId/contributions', asyncHandler(controller.recordContribution));
router.post('/clients/:userId/contributions/:historyId/reverse', asyncHandler(controller.reverseContribution));
router.get('/tontines/kyc-limits', asyncHandler(controller.getTontineKycLimits));
router.put('/tontines/kyc-limits', asyncHandler(controller.updateTontineKycLimits));
router.get('/tontines', asyncHandler(controller.tontines));
router.get('/tontines/:cycleId/calendar', asyncHandler(controller.tontineCalendar));
router.patch('/tontines/:cycleId', asyncHandler(controller.updateTontineCycle));
router.post('/tontines/:cycleId/close', asyncHandler(controller.closeTontineCycle));
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
router.get('/whatsapp/status', asyncHandler(controller.getWhatsAppStatus));
router.post('/whatsapp/refresh', asyncHandler(controller.refreshWhatsApp));

router.get('/settings', asyncHandler(controller.getSystemSettings));
router.put('/settings/:key', asyncHandler(controller.updateSystemSetting));

module.exports = router;
