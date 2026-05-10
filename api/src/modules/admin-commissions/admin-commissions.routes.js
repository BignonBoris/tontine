const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const controller = require('./admin-commissions.controller');

const router = express.Router();

router.get('/overview', authenticateAdmin, asyncHandler(controller.overview));
router.get('/agents/:agentId', authenticateAdmin, asyncHandler(controller.agentDetail));

module.exports = router;
