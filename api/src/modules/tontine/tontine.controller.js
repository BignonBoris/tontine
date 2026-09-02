const { ok } = require('../../common/utils/api-response');
const AppError = require('../../common/errors/app-error');
const { getRequestContext } = require('../../common/utils/request-context');
const {
  assertPaymentMethodEnabled,
} = require('../payment-methods/payment-methods.service');
const service = require('./tontine.service');
const fedapayService = require('./tontine-fedapay.service');
const afrikmoneyService = require('./tontine-afrikmoney.service');
const mtnMomoService = require('./tontine-mtnmomo.service');

async function getOverview(req, res) {
  const data = await service.getCycleOverview(req.auth.userId);
  return ok(res, data, 'Vue tontine chargee.');
}

async function configure(req, res) {
  if (req.body.termsAccepted !== true) {
    throw new AppError(
      "Vous devez lire et accepter les conditions générales d'épargne pour démarrer une tontine.",
      422,
    );
  }
  
  const data = await service.configureStake(
    req.auth.userId,
    req.body.stakeAmount,
    { ...getRequestContext(req), termsAccepted: true },
  );
  return ok(res, data, 'Mise configuree.');
}

async function deposit(req, res) {
  await assertPaymentMethodEnabled(
    'wallet',
    'tontine_deposit',
    "Le versement depuis le solde disponible est temporairement indisponible.",
  );
  const data = await service.depositToCycle(
    req.auth.userId,
    Number(req.body.amount),
    'wallet',
    {
      ...getRequestContext(req),
      syncId: req.body.syncId,
    },
  );
  return ok(res, data, 'Versement enregistre.');
}

async function initializeFedapayDeposit(req, res) {
  await assertPaymentMethodEnabled(
    'fedapay',
    'tontine_deposit',
    'FedaPay n est pas disponible pour le moment.',
  );
  const data = await fedapayService.initializeFedapayTontineDeposit(
    req.auth.userId,
    Number(req.body.amount),
    { ...getRequestContext(req), syncId: req.body.syncId },
  );
  return ok(res, data, 'Paiement FedaPay initialise.');
}

async function initializeAfrikmoneyDeposit(req, res) {
  await assertPaymentMethodEnabled(
    'afrikmoney',
    'tontine_deposit',
    'Afrikmoney n est pas disponible pour le moment.',
  );
  const data = await afrikmoneyService.initializeAfrikmoneyTontineDeposit(
    req.auth.userId,
    Number(req.body.amount),
    { ...getRequestContext(req), syncId: req.body.syncId },
  );
  return ok(res, data, 'Paiement Afrikmoney initialise.');
}

async function getFedapayDepositIntent(req, res) {
  const data = await fedapayService.getFedapayTontineDepositIntent(
    req.auth.userId,
    req.params.intentId,
  );
  return ok(res, data, 'Suivi du paiement charge.');
}

async function getAfrikmoneyDepositIntent(req, res) {
  const data = await afrikmoneyService.getAfrikmoneyTontineDepositIntent(
    req.auth.userId,
    req.params.intentId,
  );
  return ok(res, data, 'Suivi du paiement Afrikmoney charge.');
}

async function initializeMtnMomoDeposit(req, res) {
  await assertPaymentMethodEnabled(
    'mtn_momo',
    'tontine_deposit',
    'MTN MoMo n est pas disponible pour le moment.',
  );
  const data = await mtnMomoService.initializeMtnMomoTontineDeposit(
    req.auth.userId,
    Number(req.body.amount),
    { ...getRequestContext(req), syncId: req.body.syncId },
  );
  return ok(res, data, 'Paiement MTN MoMo initialise.');
}

async function getMtnMomoDepositIntent(req, res) {
  const data = await mtnMomoService.getMtnMomoTontineDepositIntent(
    req.auth.userId,
    req.params.intentId,
  );
  return ok(res, data, 'Suivi du paiement MTN MoMo charge.');
}

async function fedapayWebhook(req, res) {
  const data = await fedapayService.processFedapayWebhook(req);
  return ok(res, data, 'Webhook FedaPay traite.');
}

async function afrikmoneyWebhook(req, res) {
  const data = await afrikmoneyService.processAfrikmoneyWebhook(req);
  return ok(res, data, 'Webhook Afrikmoney traite.');
}

async function mtnMomoWebhook(req, res) {
  const data = await mtnMomoService.processMtnMomoWebhook(req);
  return ok(res, data, 'Webhook MTN MoMo traite.');
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

async function getKycLimits(req, res) {
  const limits = await service.listTontineKycLimits();
  const userLimit = await service.getUserEffectiveKycLimit(req.auth.userId);
  return ok(res, { limits, userLimit }, 'Plafonds KYC tontine charges.');
}

module.exports = {
  getKycLimits,
  getOverview,
  configure,
  deposit,
  initializeFedapayDeposit,
  getFedapayDepositIntent,
  initializeAfrikmoneyDeposit,
  getAfrikmoneyDepositIntent,
  initializeMtnMomoDeposit,
  getMtnMomoDepositIntent,
  fedapayWebhook,
  afrikmoneyWebhook,
  mtnMomoWebhook,
  fedapayReturnPage,
  confirmPayout,
  stopEarly,
};
