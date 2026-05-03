const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const authenticateAgent = require('../../common/middlewares/authenticate-agent');
const controller = require('./agent-provisionings.controller');

const router = express.Router();

router.get('/', authenticate, authenticateAgent, asyncHandler(controller.list));
router.post('/', authenticate, authenticateAgent, asyncHandler(controller.create));

module.exports = router;
