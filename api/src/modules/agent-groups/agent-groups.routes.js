const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const controller = require('./agent-groups.controller');
const membersController = require('./agent-group-members.controller');

const router = express.Router();

router.get('/', authenticate, authenticateAgent, asyncHandler(controller.list));
router.get(
  '/:groupId/invitation-link',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.invitationLink),
);
router.get(
  '/:groupId/members',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.list),
);
router.get(
  '/:groupId/members/:memberId/invitation-link',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.invitationLink),
);
router.get(
  '/:groupId/member-candidates',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.listCandidates),
);
router.get(
  '/:groupId/contributions',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.listContributions),
);
router.get(
  '/:groupId/advances',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.listAdvances),
);
router.get('/:groupId', authenticate, authenticateAgent, asyncHandler(controller.detail));
router.post('/', authenticate, authenticateAgent, asyncHandler(controller.create));
router.post(
  '/:groupId/members',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.add),
);
router.post(
  '/:groupId/members/:memberId/remove',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.remove),
);
router.post(
  '/:groupId/members/:memberId/approve',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.approveRequest),
);
router.post(
  '/:groupId/members/:memberId/reject',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.rejectRequest),
);
router.post(
  '/:groupId/turn-order',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.saveTurnOrder),
);
router.post(
  '/:groupId/contributions/:contributionId/pay',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.payContribution),
);
router.post(
  '/:groupId/contributions/:contributionId/advance',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.advanceContribution),
);
router.post(
  '/:groupId/advances/:advanceId/recover',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.recoverAdvance),
);
router.post(
  '/:groupId/turns/:turnId/payout',
  authenticate,
  authenticateAgent,
  asyncHandler(membersController.payoutTurn),
);
router.patch('/:groupId', authenticate, authenticateAgent, asyncHandler(controller.update));
router.post(
  '/:groupId/launch',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.launch),
);
router.post(
  '/:groupId/postpone',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.postpone),
);
router.post(
  '/:groupId/reduce-target',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.reduceTarget),
);
router.post(
  '/:groupId/cancel-launch',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.cancelLaunch),
);
router.post(
  '/:groupId/activate',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.activate),
);
router.post(
  '/:groupId/suspend',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.suspend),
);

module.exports = router;
