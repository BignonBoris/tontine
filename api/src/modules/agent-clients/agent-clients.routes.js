const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const controller = require('./agent-clients.controller');

const router = express.Router();

router.get('/', authenticate, authenticateAgent, asyncHandler(controller.search));
router.get('/mine', authenticate, authenticateAgent, asyncHandler(controller.listMine));
router.get(
  '/mine/:clientId',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.detailMine),
);
router.post('/', authenticate, authenticateAgent, asyncHandler(controller.create));
router.post(
  '/:clientId/start-tontine',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.startTontine),
);

module.exports = router;
