const express = require('express');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./app-version.admin.controller');

/**
 * @route  GET /api/v1/admin/app-versions        versions publiées (agent + client)
 * @route  PUT /api/v1/admin/app-versions/:app   publier une version (app = agent | client)
 * @access Admin
 */
const router = express.Router();

router.use(authenticateAdmin);
router.get('/', asyncHandler(controller.list));
router.put('/:app', asyncHandler(controller.update));

module.exports = router;
