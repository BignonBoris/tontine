const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const idempotency = require('../../common/middlewares/idempotency');
const controller = require('./goals.controller');

const router = express.Router();

/**
 * @swagger
 * /goals:
 *   get:
 *     tags: [Goals]
 *     summary: Lister les coffres
 *     security:
 *       - bearerAuth: []
 *   post:
 *     tags: [Goals]
 *     summary: Creer un coffre
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/GoalPayload'
 */
router.get('/', authenticate, asyncHandler(controller.listGoals));
router.get('/config', authenticate, asyncHandler(controller.getGoalConfig));
router.post('/', authenticate, asyncHandler(controller.createGoal));
router.get('/:goalId', authenticate, asyncHandler(controller.getGoal));
router.post('/:goalId/fund', authenticate, idempotency(), asyncHandler(controller.fundGoal));
router.post('/:goalId/close', authenticate, idempotency(), asyncHandler(controller.closeGoal));

module.exports = router;
