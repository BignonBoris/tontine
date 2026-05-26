const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./agent-groups.service');
const invitationService = require('../group-invitations/group-invitations.service');

async function list(req, res) {
  const data = await service.listGroups(req.agentProfile.id, req.query);
  return ok(res, data, 'Groupes charges.');
}

async function detail(req, res) {
  const data = await service.getGroupDetail(
    req.agentProfile.id,
    req.params.groupId,
  );
  return ok(res, data, 'Groupe charge.');
}

async function invitationLink(req, res) {
  const data = await invitationService.generateInvitationLink(
    req.agentProfile,
    req.params.groupId,
    getRequestContext(req),
  );
  return ok(res, data, 'Lien d invitation genere.');
}

async function create(req, res) {
  const data = await service.createGroup(
    req.agentProfile,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Groupe cree avec succes.', 201);
}

async function update(req, res) {
  const data = await service.updateGroup(
    req.agentProfile,
    req.params.groupId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Groupe mis a jour avec succes.');
}

async function launch(req, res) {
  const data = await service.launchGroup(
    req.agentProfile,
    req.params.groupId,
    getRequestContext(req),
  );
  return ok(res, data, 'Tontine de groupe demarree avec succes.');
}

async function postpone(req, res) {
  const data = await service.postponeGroupLaunch(
    req.agentProfile,
    req.params.groupId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Date de debut prolongee avec succes.');
}

async function reduceTarget(req, res) {
  const data = await service.reduceGroupTargetToCurrentMembers(
    req.agentProfile,
    req.params.groupId,
    getRequestContext(req),
  );
  return ok(res, data, 'Nombre cible reduit aux participants actuels.');
}

async function cancelLaunch(req, res) {
  const data = await service.cancelGroupLaunch(
    req.agentProfile,
    req.params.groupId,
    req.body,
    getRequestContext(req),
  );
  return ok(res, data, 'Lancement du groupe annule avec succes.');
}

async function activate(req, res) {
  const data = await service.changeGroupStatus(
    req.agentProfile,
    req.params.groupId,
    'active',
    getRequestContext(req),
  );
  return ok(res, data, 'Groupe reactive avec succes.');
}

async function suspend(req, res) {
  const data = await service.changeGroupStatus(
    req.agentProfile,
    req.params.groupId,
    'suspended',
    getRequestContext(req),
  );
  return ok(res, data, 'Groupe suspendu avec succes.');
}

module.exports = {
  list,
  invitationLink,
  detail,
  create,
  update,
  launch,
  postpone,
  reduceTarget,
  cancelLaunch,
  activate,
  suspend,
};
