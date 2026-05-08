const express = require('express');
const controller = require('./landing.controller');

const router = express.Router();

router.get('/', controller.renderHome);
router.get('/privacy', controller.renderPrivacy);
router.get('/terms', controller.renderTerms);

module.exports = router;
