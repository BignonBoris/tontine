const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./kyc.controller');

const router = express.Router();
router.get('/', authenticate, asyncHandler(controller.current));
router.post('/', authenticate, asyncHandler(controller.submit));
router.post('/documents', authenticate, asyncHandler(controller.upload));
module.exports = router;
