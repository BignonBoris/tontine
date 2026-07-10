const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./tontine.service');
const fedapayService = require('./tontine-fedapay.service');

async function getOverview(req, res) {
  const data = await service.getCycleOverview(req.auth.userId);
  return ok(res, data, 'Vue tontine chargee.');
}

async function configure(req, res) {
  const data = await service.configureStake(
    req.auth.userId,
    req.body.stakeAmount,
    getRequestContext(req),
  );
  return ok(res, data, 'Mise configuree.');
}

async function deposit(req, res) {
  const data = await service.depositToCycle(
    req.auth.userId,
    Number(req.body.amount),
    'wallet',
    getRequestContext(req),
  );
  return ok(res, data, 'Versement enregistre.');
}

async function initializeFedapayDeposit(req, res) {
  const data = await fedapayService.initializeFedapayTontineDeposit(
    req.auth.userId,
    Number(req.body.amount),
    getRequestContext(req),
  );
  return ok(res, data, 'Paiement FedaPay initialise.');
}

async function getFedapayDepositIntent(req, res) {
  const data = await fedapayService.getFedapayTontineDepositIntent(
    req.auth.userId,
    req.params.intentId,
  );
  return ok(res, data, 'Suivi du paiement charge.');
}

async function fedapayWebhook(req, res) {
  const data = await fedapayService.processFedapayWebhook(req);
  return ok(res, data, 'Webhook FedaPay traite.');
}

async function fedapayReturnPage(req, res) {
  return fedapayService.renderFedapayReturnPage(req, res);
}

async function confirmPayout(req, res) {
  const data = await service.confirmCyclePayout(
    req.auth.userId,
    getRequestContext(req),
  );
  return ok(res, data, 'Reversement confirme.');
}

async function stopEarly(req, res) {
  const data = await service.stopCycleEarly(
    req.auth.userId,
    getRequestContext(req),
  );
  return ok(res, data, 'Tontine arretee.');
}

module.exports = {
  getOverview,
  configure,
  deposit,
  initializeFedapayDeposit,
  getFedapayDepositIntent,
  fedapayWebhook,
  fedapayReturnPage,
  confirmPayout,
  stopEarly,
};
