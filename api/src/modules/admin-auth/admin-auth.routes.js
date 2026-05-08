const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const controller = require('./admin-auth.controller');

const router = express.Router();

router.post('/login', asyncHandler(controller.login));
router.get('/session', authenticateAdmin, asyncHandler(controller.session));

module.exports = router;
