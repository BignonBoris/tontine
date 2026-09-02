const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./goal-templates.controller');

const router = express.Router();

/**
 * @swagger
 * /goal-templates:
 *   get:
 *     tags: [GoalTemplates]
 *     summary: Lister les coffres par defaut actifs (onboarding)
 *     security:
 *       - bearerAuth: []
 * /goal-templates/apply:
 *   post:
 *     tags: [GoalTemplates]
 *     summary: Creer les coffres choisis par le client (1 a 3 max)
 *     security:
 *       - bearerAuth: []
 */
router.get('/', authenticate, asyncHandler(controller.listTemplates));
router.post('/apply', authenticate, asyncHandler(controller.applyTemplates));

module.exports = router;
