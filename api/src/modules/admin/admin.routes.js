const express = require('express');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./admin.controller');

const router = express.Router();

router.use(authenticateAdmin);

router.get('/overview', asyncHandler(controller.overview));
router.get('/anomalies', asyncHandler(controller.anomalies));
router.get('/clients', asyncHandler(controller.clients));
router.get('/clients/:userId', asyncHandler(controller.clientDetail));
router.patch('/clients/:userId/status', asyncHandler(controller.updateClientStatus));
router.get('/agents', asyncHandler(controller.agents));
router.patch('/agents/:agentId/status', asyncHandler(controller.updateAgentStatus));
router.post('/agents/:agentId/top-up', asyncHandler(controller.topUpAgentCash));
router.get('/agents/:agentId/cash-history', asyncHandler(controller.agentCashHistory));
router.get('/withdrawals', asyncHandler(controller.withdrawals));
router.get('/withdrawals/:withdrawalId', asyncHandler(controller.withdrawalDetail));
router.get('/audit-logs', asyncHandler(controller.auditLogs));

module.exports = router;
