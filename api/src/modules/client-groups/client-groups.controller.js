const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./client-groups.service');

async function list(req, res) {
  const data = await service.listMyGroups(req.auth.userId);
  return ok(res, data, 'Vos groupes de tontine ont ete charges.');
}

async function listRequests(req, res) {
  const data = await service.listMyGroupRequests(req.auth.userId);
  return ok(res, data, 'Vos demandes de groupe ont ete chargees.');
}

async function detail(req, res) {
  const data = await service.getMyGroupDetail(req.auth.userId, req.params.groupId);
  return ok(res, data, 'Detail du groupe charge.');
}

async function contributions(req, res) {
  const data = await service.listMyGroupContributions(
    req.auth.userId,
    req.params.groupId,
  );
  return ok(res, data, 'Vos cotisations de groupe ont ete chargees.');
}

async function payContribution(req, res) {
  const data = await service.payContributionFromWallet(
    req.auth.userId,
    req.params.contributionId,
    getRequestContext(req),
  );
  return ok(res, data, 'Cotisation de groupe payee avec succes.');
}

module.exports = {
  list,
  listRequests,
  detail,
  contributions,
  payContribution,
};
