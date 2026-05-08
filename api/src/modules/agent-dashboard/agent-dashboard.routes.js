const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const controller = require('./agent-dashboard.controller');

const router = express.Router();

router.get('/', authenticate, authenticateAgent, asyncHandler(controller.overview));
router.get(
  '/commissions',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.commissions),
);

module.exports = router;
