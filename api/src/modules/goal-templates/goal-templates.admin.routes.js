const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const controller = require('./goal-templates.controller');

const router = express.Router();

router.get('/', authenticateAdmin, asyncHandler(controller.adminList));
router.post('/', authenticateAdmin, asyncHandler(controller.adminCreate));
router.put('/:id', authenticateAdmin, asyncHandler(controller.adminUpdate));
router.delete('/:id', authenticateAdmin, asyncHandler(controller.adminDelete));

module.exports = router;
