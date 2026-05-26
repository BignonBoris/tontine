const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-group-members.service');
const invitationService = require('../group-invitations/group-invitations.service');
const contributionsService = require('./agent-group-contributions.service');

async function list(req, res) {
  const data = await service.listGroupMembers(
    req.agentProfile.id,
    req.params.groupId,
    req.query,
  );
  return ok(res, data, 'Participants du groupe charges.');
}

async function listCandidates(req, res) {
  const data = await service.listGroupMemberCandidates(
    req.agentProfile.id,
    req.params.groupId,
    req.query.q,
  );
  return ok(res, data, 'Candidats au groupe charges.');
}

async function add(req, res) {
  const data = await service.addGroupMember(
    req.agentProfile,
    req.params.groupId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Invitation du participant creee avec succes.', 201);
}

async function remove(req, res) {
  const data = await service.removeGroupMember(
    req.agentProfile,
    req.params.groupId,
    req.params.memberId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Participant retire du groupe.');
}

async function invitationLink(req, res) {
  const data = await invitationService.generateMemberInvitationLink(
    req.agentProfile,
    req.params.groupId,
    req.params.memberId,
    getRequestContext(req),
  );
  return ok(res, data, 'Lien d invitation nominative genere.');
}

async function approveRequest(req, res) {
  const data = await service.approveGroupMemberRequest(
    req.agentProfile,
    req.params.groupId,
    req.params.memberId,
    getRequestContext(req),
  );
  return ok(res, data, 'Demande d adhesion validee avec succes.');
}

async function rejectRequest(req, res) {
  const data = await service.rejectGroupMemberRequest(
    req.agentProfile,
    req.params.groupId,
    req.params.memberId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Demande d adhesion refusee avec succes.');
}

async function saveTurnOrder(req, res) {
  const data = await service.saveGroupTurnOrder(
    req.agentProfile,
    req.params.groupId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Ordre des tours enregistre avec succes.');
}

async function listContributions(req, res) {
  const data = await contributionsService.listGroupContributions(
    req.agentProfile.id,
    req.params.groupId,
    req.query,
  );
  return ok(res, data, 'Contributions du groupe chargees.');
}

async function payContribution(req, res) {
  const data = await contributionsService.payContributionByAgent(
    req.agentProfile,
    req.params.groupId,
    req.params.contributionId,
    getRequestContext(req),
  );
  return ok(res, data, 'Contribution de groupe enregistree avec succes.');
}

module.exports = {
  list,
  listCandidates,
  add,
  remove,
  invitationLink,
  approveRequest,
  rejectRequest,
  saveTurnOrder,
  listContributions,
  payContribution,
};
