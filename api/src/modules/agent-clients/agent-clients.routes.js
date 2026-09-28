const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const controller = require('./agent-clients.controller');
const multer = require('multer');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });


router.get('/', authenticate, authenticateAgent, asyncHandler(controller.search));
router.get('/mine', authenticate, authenticateAgent, asyncHandler(controller.listMine));
router.get(
  '/mine/:clientId',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.detailMine),
);
router.post('/', authenticate, authenticateAgent, asyncHandler(controller.create));
router.post(
  '/:clientId/start-tontine',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.startTontine),
);
router.post(
  '/:clientId/close-tontine',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.closeTontine),
);
router.post(
  '/:clientId/kyc',
  authenticate,
  authenticateAgent,
  upload.fields([{ name: 'front', maxCount: 1 }, { name: 'back', maxCount: 1 }, { name: 'selfie', maxCount: 1 }]),
  asyncHandler(controller.uploadKyc),
);

router.put(
  '/:clientId/phone',
  authenticate,
  authenticateAgent,
  asyncHandler(controller.updatePhone)
);

module.exports = router;
