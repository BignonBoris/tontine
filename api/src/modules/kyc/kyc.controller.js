const { ok } = require('../../common/utils/api-response');
const { getRequestContext } = require('../../common/utils/request-context');
const service = require('./kyc.service');

async function current(req, res) { return ok(res, await service.getCurrentCase(req.auth.userId), 'Statut KYC charge.'); }
async function submit(req, res) { return ok(res, await service.submitCase(req.auth.userId, req.body, getRequestContext(req)), 'Dossier KYC soumis.', 201); }
async function upload(req, res) { return ok(res, await service.uploadDocument(req.auth.userId, req.query, req, getRequestContext(req)), 'Document KYC televerse.', 201); }
async function list(req, res) { return ok(res, await service.listCases(req.query), 'Dossiers KYC charges.'); }
async function detail(req, res) { return ok(res, await service.getCase(req.params.caseId), 'Dossier KYC charge.'); }
async function document(req, res) {
  const file = await service.getDocumentForAdmin(req.params.documentId);
  res.type(file.contentType);
  res.setHeader('Content-Disposition', `inline; filename="${file.fileName}"`);
  return res.sendFile(file.absolutePath);
}
async function review(req, res) { return ok(res, await service.reviewCase(req.params.caseId, req.body, { ipAddress: req.ip || null, userAgent: req.get('user-agent') || null, adminUsername: req.admin?.username || null }), 'Dossier KYC traite.'); }

module.exports = { current, submit, upload, list, detail, document, review };
