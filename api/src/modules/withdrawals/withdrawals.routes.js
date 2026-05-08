const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./withdrawals.controller');

const router = express.Router();

router.get('/', authenticate, asyncHandler(controller.list));
router.post('/', authenticate, asyncHandler(controller.create));
router.post('/:withdrawalId/cancel', authenticate, asyncHandler(controller.cancel));
router.post(
  '/:withdrawalId/regenerate-code',
  authenticate,
  asyncHandler(controller.regenerateCode),
);

module.exports = router;
