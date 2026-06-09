const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticate = require('../../common/middlewares/authenticate');
const controller = require('./group-invitations.controller');

const router = express.Router();

router.get('/:token', asyncHandler(controller.preview));
router.post('/:token/accept', authenticate, asyncHandler(controller.accept));
router.post('/:token/decline', authenticate, asyncHandler(controller.decline));

module.exports = router;
