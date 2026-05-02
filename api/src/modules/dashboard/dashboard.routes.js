const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./dashboard.controller');

const router = express.Router();

/**
 * @swagger
 * /dashboard:
 *   get:
 *     tags: [Dashboard]
 *     summary: Recuperer le dashboard mobile du MVP
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dashboard charge
 */
router.get('/', authenticate, asyncHandler(controller.getSummary));

module.exports = router;
