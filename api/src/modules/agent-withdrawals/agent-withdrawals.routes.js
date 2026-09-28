const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./agent-withdrawals.controller');

const router = express.Router();

// Rechercher un retrait par référence (mode référence client)
router.get(
  '/search',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.searchByReference),
);

// Prévisualiser / valider client + montant (étape 1 du mode direct)
router.post(
  '/preview',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.preview),
);

// Créer un retrait pour un client (étape 1.5 du mode direct — génère OTP)
router.post(
  '/create',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.create),
);

// Payer un retrait avec le code OTP client
router.post(
  '/:withdrawalId/pay',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.pay),
);

module.exports = router;
