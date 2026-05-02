const { ok } = require('../../common/utils/api-response');
const service = require('./wallet.service');

async function getWallet(req, res) {
  const data = await service.getWallet(req.auth.userId);
  return ok(res, data, 'Portefeuille charge.');
}

module.exports = { getWallet };
