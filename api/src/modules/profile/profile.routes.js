const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./profile.controller');

const router = express.Router();

/**
 * @swagger
 * /profile:
 *   get:
 *     tags: [Profile]
 *     summary: Recuperer le profil courant
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Profil
 *   patch:
 *     tags: [Profile]
 *     summary: Mettre a jour le profil courant
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/ProfilePayload'
 *     responses:
 *       200:
 *         description: Profil mis a jour
 */
router.get('/', authenticate, asyncHandler(controller.getProfile));
router.patch('/', authenticate, asyncHandler(controller.updateProfile));

/**
 * @swagger
 * /profile/preferences:
 *   patch:
 *     tags: [Profile]
 *     summary: Mettre a jour les preferences du profil
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/PreferencesPayload'
 *     responses:
 *       200:
 *         description: Preferences mises a jour
 */
router.patch(
  '/preferences',
  authenticate,
  asyncHandler(controller.updatePreferences),
);

module.exports = router;
