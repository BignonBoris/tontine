const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./client-groups.controller');

const router = express.Router();

router.get('/', authenticate, asyncHandler(controller.list));
router.get('/requests', authenticate, asyncHandler(controller.listRequests));
router.post(
  '/contributions/:contributionId/pay',
  authenticate,
  asyncHandler(controller.payContribution),
);
router.get(
  '/:groupId/contributions',
  authenticate,
  asyncHandler(controller.contributions),
);
router.get(
  '/:groupId/advances',
  authenticate,
  asyncHandler(controller.advances),
);
router.get(
  '/:groupId/advance-recoveries',
  authenticate,
  asyncHandler(controller.advanceRecoveries),
);
router.get('/:groupId', authenticate, asyncHandler(controller.detail));

module.exports = router;
