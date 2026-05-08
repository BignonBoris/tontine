const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./agent-cash.controller');

const router = express.Router();

router.get('/', authenticate, authenticateAgent, asyncHandler(controller.overview));
router.post(
  '/top-up',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.topUp),
);

module.exports = router;
