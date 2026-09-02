const express = require('express');
const adminReconciliationController = require('./admin-reconciliation.controller');
const authenticateAdmin = require('../../common/middlewares/authenticate-admin');

const router = express.Router();

router.use(authenticateAdmin);

router.get(
  '/reconciliation/run',
  adminReconciliationController.runReconciliation,
);

module.exports = router;
