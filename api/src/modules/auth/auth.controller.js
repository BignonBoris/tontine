const { ok } = require('../../common/utils/api-response');
const authService = require('./auth.service');

function getRequestContext(req) {
  return {
    ipAddress: req.ip,
    userAgent: req.headers['user-agent'] || null,
  };
}

async function requestOtp(req, res) {
  const data = await authService.requestOtp(req.body, getRequestContext(req));
  return ok(res, data, 'Code OTP genere.');
}

async function resendOtp(req, res) {
  const data = await authService.resendOtp(req.body, getRequestContext(req));
  return ok(res, data, 'Nouveau code OTP genere.');
}

async function verifyOtp(req, res) {
  const data = await authService.verifyOtp(req.body, getRequestContext(req));
  return ok(res, data, 'Verification reussie.');
}

async function me(req, res) {
  const data = await authService.getCurrentUserProfile(req.auth.userId);
  return ok(res, data, 'Profil courant charge.');
}

module.exports = { requestOtp, resendOtp, verifyOtp, me };
