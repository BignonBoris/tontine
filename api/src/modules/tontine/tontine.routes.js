const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./tontine.controller');

const router = express.Router();

/**
 * @swagger
 * /tontine:
 *   get:
 *     tags: [Tontine]
 *     summary: Recuperer la vue complete de la tontine
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Vue tontine
 */
router.get('/', authenticate, asyncHandler(controller.getOverview));
router.post('/configure', authenticate, asyncHandler(controller.configure));
router.post('/deposit', authenticate, asyncHandler(controller.deposit));
router.post(
  '/confirm-payout',
  authenticate,
  asyncHandler(controller.confirmPayout),
);
router.post('/stop-early', authenticate, asyncHandler(controller.stopEarly));

module.exports = router;
