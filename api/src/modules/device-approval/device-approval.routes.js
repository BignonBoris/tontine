const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./device-approval.controller');

const router = express.Router();
router.get('/:requestId/status', asyncHandler(controller.status));
router.get('/pending', authenticate, asyncHandler(controller.getPending));
router.post('/:requestId/approve', authenticate, asyncHandler(controller.approve));
router.post('/:requestId/reject', authenticate, asyncHandler(controller.reject));

module.exports = router;
