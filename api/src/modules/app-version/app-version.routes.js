const express = require('express');
const asyncHandler = require('../../common/utils/async-handler');
const { getVersion } = require('./app-version.controller');

/**
 * @route  GET /api/v1/app-version/:app   (app = agent | client)
 * @route  GET /api/v1/agent/app-version  (alias = agent)
 * @desc   Version publiée de l'application mobile, pour les mises à jour hors Play Store
 * @access Public (pas de JWT requis — consulté avant login si nécessaire)
 */
const router = express.Router();
router.get('/:app', asyncHandler(getVersion));

const agentAliasRouter = express.Router();
agentAliasRouter.get('/', asyncHandler(getVersion));

module.exports = { router, agentAliasRouter };
