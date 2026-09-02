const express = require('express');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./payment-methods.admin.controller');

const router = express.Router();

router.use(authenticateAdmin);

router.get('/', asyncHandler(controller.list));
router.patch('/:methodId', asyncHandler(controller.toggle));

module.exports = router;
