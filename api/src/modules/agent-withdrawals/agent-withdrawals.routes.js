const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./agent-withdrawals.controller');

const router = express.Router();

router.get(
  '/search',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.searchByReference),
);
router.post(
  '/:withdrawalId/pay',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.pay),
);

module.exports = router;
