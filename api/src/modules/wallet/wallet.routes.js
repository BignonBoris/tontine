const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./wallet.controller');

const router = express.Router();

/**
 * @swagger
 * /wallet:
 *   get:
 *     tags: [Wallet]
 *     summary: Recuperer le portefeuille et son historique
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Portefeuille charge
 */
router.get('/', authenticate, asyncHandler(controller.getWallet));

module.exports = router;
