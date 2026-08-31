const { Op } = require('sequelize');
const crypto = require('node:crypto');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const AppError = require('../../common/errors/app-error');
const { models, sequelize } = require('../../database/models');
const { writeAuditLog } = require('../../common/services/audit-log.service');

const DOCUMENT_TYPES = new Set(['cni', 'passport', 'residence_permit']);
const REVIEW_DECISIONS = new Set(['verified', 'rejected', 'suspended']);
const MAX_DOCUMENT_BYTES = 5 * 1024 * 1024;
const PRIVATE_KYC_ROOT = path.join(__dirname, '../../private-storage/kyc');

function serializeCase(kycCase, includeSensitive = false) {
  return {
    id: kycCase.id,
    status: kycCase.status,
    level: kycCase.level,
    submittedAt: kycCase.submittedAt,
    reviewedAt: kycCase.reviewedAt,
    expiresAt: kycCase.expiresAt,
    rejectionReason: kycCase.rejectionReason,
    documents: (kycCase.documents || []).map((document) => ({
      id: document.id,
      documentType: document.documentType,
      countryCode: document.countryCode,
      documentNumber: includeSensitive ? document.documentNumber : null,
      status: document.status,
      submittedAt: document.submittedAt,
    })),
  };
}

async function loadCase(userId) {
  return models.KycCase.findOne({
    where: { userId },
    include: [{ model: models.KycDocument, as: 'documents' }],
  });
}

async function getCurrentCase(userId) {
  const kycCase = await loadCase(userId);
  return kycCase ? serializeCase(kycCase) : { status: 'unverified', level: 'basic', documents: [] };
}

async function submitCase(userId, payload, requestContext = {}) {
  const documentType = String(payload.documentType || '').trim().toLowerCase();
  const countryCode = String(payload.countryCode || 'BJ').trim().toUpperCase();
  const documentNumber = String(payload.documentNumber || '').trim();
  const storageKey = String(payload.storageKey || '').trim();

  if (!DOCUMENT_TYPES.has(documentType)) {
    throw new AppError('Type de document KYC non pris en charge.', 422);
  }
  if (countryCode !== 'BJ') {
    throw new AppError('Le pays de lancement accepte pour ce parcours est le Benin.', 422);
  }
  if (!documentNumber || documentNumber.length > 120) {
    throw new AppError('Le numero du document est requis et invalide.', 422);
  }
  if (!storageKey) {
    throw new AppError('La piece du document doit etre televersee avant la soumission.', 422);
  }
  if (storageKey.length > 500) {
    throw new AppError('La reference du document est invalide.', 422);
  }

  const existing = await loadCase(userId);
  if (existing?.status === 'pending_review') {
    throw new AppError('Votre dossier KYC est deja en cours de verification.', 409);
  }

  const result = await sequelize.transaction(async (transaction) => {
    const [kycCase] = await models.KycCase.findOrCreate({
      where: { userId },
      defaults: { userId, status: 'unverified', level: 'basic' },
      transaction,
    });

    await models.KycDocument.destroy({ where: { kycCaseId: kycCase.id }, transaction });
    await models.KycDocument.create(
      { kycCaseId: kycCase.id, documentType, countryCode, documentNumber, storageKey: storageKey || null },
      { transaction },
    );
    await kycCase.update(
      { status: 'pending_review', submittedAt: new Date(), reviewedAt: null, expiresAt: null, rejectionReason: null },
      { transaction },
    );
    return kycCase;
  });

  await writeAuditLog({
    userId,
    action: 'kyc.submitted',
    entityType: 'kycCase',
    entityId: result.id,
    ...requestContext,
    metadata: { documentType, countryCode },
  });
  return getCurrentCase(userId);
}

async function uploadDocument(userId, payload, request, requestContext = {}) {
  const documentType = String(payload.documentType || '').trim().toLowerCase();
  const countryCode = String(payload.countryCode || 'BJ').trim().toUpperCase();
  const documentNumber = String(payload.documentNumber || '').trim();
  const contentType = String(request.headers['content-type'] || '').split(';')[0].toLowerCase();
  const allowedTypes = new Map([
    ['image/jpeg', '.jpg'],
    ['image/png', '.png'],
    ['application/pdf', '.pdf'],
  ]);

  if (!DOCUMENT_TYPES.has(documentType) || countryCode !== 'BJ') {
    throw new AppError('Type de document ou pays invalide.', 422);
  }
  if (!documentNumber || documentNumber.length > 120) {
    throw new AppError('Le numero du document est requis et invalide.', 422);
  }
  if (!allowedTypes.has(contentType)) {
    throw new AppError('Format de document non accepte. Utilisez JPG, PNG ou PDF.', 415);
  }
  const declaredLength = Number(request.headers['content-length'] || 0);
  if (declaredLength > MAX_DOCUMENT_BYTES) {
    throw new AppError('Le document ne doit pas depasser 5 Mo.', 413);
  }

  const existing = await loadCase(userId);
  if (existing?.status === 'pending_review') {
    throw new AppError('Votre dossier KYC est deja en cours de verification.', 409);
  }

  const fileId = crypto.randomUUID();
  const storageKey = `${fileId}${allowedTypes.get(contentType)}`;
  const absolutePath = path.join(PRIVATE_KYC_ROOT, storageKey);
  await fsp.mkdir(PRIVATE_KYC_ROOT, { recursive: true });

  let size = 0;
  const hash = crypto.createHash('sha256');
  const output = fs.createWriteStream(absolutePath, { flags: 'wx', mode: 0o600 });
  try {
    await new Promise((resolve, reject) => {
      request.on('data', (chunk) => {
        size += chunk.length;
        if (size > MAX_DOCUMENT_BYTES) {
          request.destroy(new AppError('Le document ne doit pas depasser 5 Mo.', 413));
          return;
        }
        hash.update(chunk);
      });
      request.on('error', reject);
      output.on('error', reject);
      output.on('finish', resolve);
      request.pipe(output);
    });

    const kycCase = await sequelize.transaction(async (transaction) => {
      const [currentCase] = await models.KycCase.findOrCreate({
        where: { userId },
        defaults: { userId, status: 'unverified', level: 'basic' },
        transaction,
      });
      const now = new Date();
      await models.KycDocument.create({ kycCaseId: currentCase.id, documentType, countryCode, documentNumber, storageKey, metadata: { contentType, size, sha256: hash.digest('hex') } }, { transaction });
      await currentCase.update({ status: 'pending_review', submittedAt: now, reviewedAt: null, expiresAt: null, rejectionReason: null }, { transaction });
      return currentCase;
    });

    await writeAuditLog({ userId, action: 'kyc.document_uploaded', entityType: 'kycCase', entityId: kycCase.id, ...requestContext, metadata: { documentType, contentType, size } });
    return getCurrentCase(userId);
  } catch (error) {
    await fsp.unlink(absolutePath).catch(() => {});
    throw error;
  }
}

async function listCases(query = {}) {
  const status = String(query.status || '').trim();
  const where = status ? { status } : { status: { [Op.in]: ['pending_review', 'rejected', 'expired', 'suspended'] } };
  const cases = await models.KycCase.findAll({
    where,
    include: [
      { model: models.User, as: 'user', required: true, attributes: ['id', 'displayName', 'firstName', 'lastName', 'phoneNumber'] },
      { model: models.KycDocument, as: 'documents' },
    ],
    order: [['submittedAt', 'ASC']],
    limit: Math.min(Math.max(Number(query.limit) || 50, 1), 100),
  });
  return cases.map((entry) => ({
    ...serializeCase(entry, true),
    user: entry.user
      ? { id: entry.user.id, displayName: entry.user.displayName, firstName: entry.user.firstName, lastName: entry.user.lastName, phoneNumber: entry.user.phoneNumber }
      : null,
  }));
}

async function getCase(caseId) {
  const entry = await models.KycCase.findByPk(caseId, {
    include: [
      { model: models.User, as: 'user', required: true, attributes: ['id', 'displayName', 'firstName', 'lastName', 'phoneNumber', 'birthDate'] },
      { model: models.KycDocument, as: 'documents' },
      { model: models.KycDecision, as: 'decisions', order: [['decidedAt', 'DESC']] },
    ],
  });
  if (!entry) throw new AppError('Dossier KYC introuvable.', 404);
  return {
    ...serializeCase(entry, true),
    user: entry.user,
    decisions: (entry.decisions || []).map((decision) => ({ id: decision.id, decision: decision.decision, reason: decision.reason, decidedBy: decision.decidedBy, decidedAt: decision.decidedAt })),
  };
}

async function getDocumentForAdmin(documentId) {
  const document = await models.KycDocument.findByPk(documentId, {
    include: [{ model: models.KycCase, as: 'kycCase' }],
  });
  if (!document || !document.storageKey) throw new AppError('Document KYC introuvable.', 404);
  const root = path.resolve(PRIVATE_KYC_ROOT);
  const absolutePath = path.resolve(root, document.storageKey);
  if (!absolutePath.startsWith(`${root}${path.sep}`)) throw new AppError('Reference de document invalide.', 400);
  try {
    await fsp.access(absolutePath, fs.constants.R_OK);
  } catch (_) {
    throw new AppError('Fichier KYC indisponible.', 404);
  }
  return { absolutePath, contentType: document.metadata?.contentType || 'application/octet-stream', fileName: `${document.documentType}-${document.id}${path.extname(document.storageKey)}` };
}

async function reviewCase(caseId, payload, adminContext = {}) {
  const decision = String(payload.decision || '').trim().toLowerCase();
  const reason = String(payload.reason || '').trim();
  if (!REVIEW_DECISIONS.has(decision)) throw new AppError('Decision KYC invalide.', 422);
  if (decision === 'rejected' && !reason) throw new AppError('Un motif est obligatoire pour un rejet.', 422);

  const kycCase = await models.KycCase.findByPk(caseId);
  if (!kycCase) throw new AppError('Dossier KYC introuvable.', 404);
  if (kycCase.status !== 'pending_review') throw new AppError('Ce dossier ne peut plus etre traite dans son etat actuel.', 409);

  const now = new Date();
  await sequelize.transaction(async (transaction) => {
    await kycCase.update({ status: decision, reviewedAt: now, rejectionReason: decision === 'rejected' ? reason : null, expiresAt: decision === 'verified' ? new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000) : null }, { transaction });
    await models.KycDecision.create({ kycCaseId, decision, reason: reason || null, decidedBy: adminContext.adminUsername || 'admin' }, { transaction });
  });
  await writeAuditLog({ userId: null, action: `kyc.${decision}`, entityType: 'kycCase', entityId: caseId, ipAddress: adminContext.ipAddress, userAgent: adminContext.userAgent, metadata: { adminUsername: adminContext.adminUsername || null, reason: reason || null } });
  const updated = await getCase(caseId);
  return updated;
}

module.exports = { getCurrentCase, submitCase, uploadDocument, listCases, getCase, getDocumentForAdmin, reviewCase };
