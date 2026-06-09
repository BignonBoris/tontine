const { ok } = require('../../common/utils/api-response');
const service = require('./group-invitations.service');

async function preview(req, res) {
  const data = await service.getInvitationPreview(req.params.token);
  return ok(res, data, 'Invitation de groupe chargee.');
}

async function accept(req, res) {
  const data = await service.acceptInvitation(
    req.params.token,
    req.auth.userId,
    {
      ipAddress: req.ip || null,
      userAgent: req.get('user-agent') || null,
    },
  );
  return ok(res, data, 'Invitation acceptee avec succes.');
}

async function decline(req, res) {
  const data = await service.declineInvitation(
    req.params.token,
    req.auth.userId,
    {
      ipAddress: req.ip || null,
      userAgent: req.get('user-agent') || null,
    },
  );
  return ok(res, data, 'Invitation refusee avec succes.');
}

module.exports = { preview, accept, decline };
