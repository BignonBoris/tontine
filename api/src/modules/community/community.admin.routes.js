const express = require('express');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./community.admin.controller');

/**
 * Assistant Community Manager (admin uniquement).
 * @route GET   /api/v1/admin/community/options
 * @route GET   /api/v1/admin/community/brand-profile
 * @route PUT   /api/v1/admin/community/brand-profile
 * @route POST  /api/v1/admin/community/generate      publications (brouillons)
 * @route POST  /api/v1/admin/community/replies       reponse a un commentaire
 * @route GET   /api/v1/admin/community/posts         ?status&kind&network&language&needsSupport&page&limit
 * @route PATCH /api/v1/admin/community/posts/:id     edition / statut
 */
const router = express.Router();

router.use(authenticateAdmin);
router.get('/options', asyncHandler(controller.options));
router.get('/brand-profile', asyncHandler(controller.getBrandProfile));
router.put('/brand-profile', asyncHandler(controller.updateBrandProfile));
router.post('/generate', asyncHandler(controller.generate));
router.post('/replies', asyncHandler(controller.reply));
router.get('/posts', asyncHandler(controller.list));
router.patch('/posts/:id', asyncHandler(controller.update));

module.exports = router;
