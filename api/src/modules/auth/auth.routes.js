const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const controller = require('./auth.controller');

const router = express.Router();

/**
 * @swagger
 * /auth/request-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Demander un OTP de connexion ou d'inscription
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/AuthOtpRequest'
 *     responses:
 *       200:
 *         description: OTP genere
 */
router.post('/request-otp', asyncHandler(controller.requestOtp));

/**
 * @swagger
 * /auth/resend-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Regenerer un OTP
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/AuthOtpRequest'
 *     responses:
 *       200:
 *         description: OTP renvoye
 */
router.post('/resend-otp', asyncHandler(controller.resendOtp));

/**
 * @swagger
 * /auth/verify-otp:
 *   post:
 *     tags: [Auth]
 *     summary: Verifier le code OTP et ouvrir la session
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/AuthOtpVerify'
 *     responses:
 *       200:
 *         description: Session ouverte
 */
router.post('/verify-otp', asyncHandler(controller.verifyOtp));

/**
 * @swagger
 * /auth/me:
 *   get:
 *     tags: [Auth]
 *     summary: Recuperer l'utilisateur courant
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Utilisateur courant
 */
router.get('/me', authenticate, asyncHandler(controller.me));

module.exports = router;
