const { ok } = require('../../common/utils/api-response');
const service = require('./client-group-invitations.service');

async function list(req, res) {
  const data = await service.listMyPendingGroupInvitations(req.auth.userId);
  return ok(res, data, 'Vos invitations de groupe ont ete chargees.');
}

module.exports = {
  list,
};
