const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./tontine.controller');

const router = express.Router();

router.get('/fedapay/return', asyncHandler(controller.fedapayReturnPage));
router.post('/fedapay/webhook', asyncHandler(controller.fedapayWebhook));
router.post(
  '/fedapay/deposits',
  authenticate,
  asyncHandler(controller.initializeFedapayDeposit),
);
router.get(
  '/fedapay/deposits/:intentId',
  authenticate,
  asyncHandler(controller.getFedapayDepositIntent),
);
router.post(
  '/afrikmoney/deposits',
  authenticate,
  asyncHandler(controller.initializeAfrikmoneyDeposit),
);
router.get(
  '/afrikmoney/deposits/:intentId',
  authenticate,
  asyncHandler(controller.getAfrikmoneyDepositIntent),
);
router.post('/afrikmoney/webhook', asyncHandler(controller.afrikmoneyWebhook));
router.post(
  '/mtn-momo/deposits',
  authenticate,
  asyncHandler(controller.initializeMtnMomoDeposit),
);
router.get(
  '/mtn-momo/deposits/:intentId',
  authenticate,
  asyncHandler(controller.getMtnMomoDepositIntent),
);
router.post('/mtn-momo/webhook', asyncHandler(controller.mtnMomoWebhook));
router.put('/mtn-momo/webhook', asyncHandler(controller.mtnMomoWebhook));

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
router.get('/kyc-limits', authenticate, asyncHandler(controller.getKycLimits));
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
