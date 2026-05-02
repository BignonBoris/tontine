const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./notifications.controller');

const router = express.Router();

/**
 * @swagger
 * /notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: Lister les notifications de l'utilisateur
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Notifications
 */
router.get('/', authenticate, asyncHandler(controller.listNotifications));
router.post(
  '/:notificationId/read',
  authenticate,
  asyncHandler(controller.markAsRead),
);
router.post('/read-all', authenticate, asyncHandler(controller.markAllAsRead));

module.exports = router;
