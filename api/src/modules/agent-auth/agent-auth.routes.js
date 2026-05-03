const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./agent-auth.controller');

const router = express.Router();

/**
 * @swagger
 * /agent/auth/login:
 *   post:
 *     tags: [Agent]
 *     summary: Ouvrir une session agent
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/AgentLoginPayload'
 *     responses:
 *       200:
 *         description: Session agent ouverte
 */
router.post('/login', asyncHandler(controller.login));

module.exports = router;
