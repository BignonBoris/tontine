const express = require('express');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');
const asyncHandler = require('../../common/utils/async-handler');
const controller = require('./kyc.controller');

const router = express.Router();
router.use(authenticateAdmin);
router.get('/', asyncHandler(controller.list));
router.get('/documents/:documentId', asyncHandler(controller.document));
router.get('/:caseId', asyncHandler(controller.detail));
router.post('/:caseId/review', asyncHandler(controller.review));
module.exports = router;
