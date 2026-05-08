const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./admin-auth.controller');

const router = express.Router();

router.post('/login', asyncHandler(controller.login));

module.exports = router;
