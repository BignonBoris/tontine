const express = require('express');
const authenticate = require('../../common/middlewares/authenticate');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./client-group-invitations.controller');

const router = express.Router();

router.get('/', authenticate, asyncHandler(controller.list));

module.exports = router;
