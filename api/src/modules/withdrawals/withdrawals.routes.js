const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const controller = require('./withdrawals.controller');

const router = express.Router();

router.get('/', authenticate, asyncHandler(controller.list));
router.post('/', authenticate, asyncHandler(controller.create));
router.post('/:withdrawalId/cancel', authenticate, asyncHandler(controller.cancel));
router.get(
  '/agent/search',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.search),
);
router.post(
  '/agent/:withdrawalId/pay',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.pay),
);

module.exports = router;
