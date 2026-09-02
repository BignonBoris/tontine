const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

const DEFAULT_KYC_LIMITS = [
  {
    kycStatus: 'unverified',
    tierLevel: 'tier_0',
    label: 'Palier 0 - Non vérifié',
    description: 'Compte identifié par téléphone. Plafonds de base conformes réglementation SFD/BCEAO.',
    maxDailyStake: 2000,
    maxCycleCumulative: 62000,
    allowMultipleCycles: false,
    enabled: true,
  },
  {
    kycStatus: 'pending_review',
    tierLevel: 'tier_1',
    label: 'Palier 1 - En cours de revue',
    description: 'Document officiel soumis en cours de vérification par les officiers de conformité.',
    maxDailyStake: 10000,
    maxCycleCumulative: 310000,
    allowMultipleCycles: false,
    enabled: true,
  },
  {
    kycStatus: 'verified',
    tierLevel: 'tier_2',
    label: 'Palier 2 - Identité certifiée',
    description: 'Document d\'identité (CNI / CIP / Passeport) validé. Plafonds élevés débloqués.',
    maxDailyStake: 50000,
    maxCycleCumulative: 1550000,
    allowMultipleCycles: true,
    enabled: true,
  },
];

async function ensureDefaultLimits() {
  await models.TontineKycLimit.sync();
  for (const def of DEFAULT_KYC_LIMITS) {
    const existing = await models.TontineKycLimit.findOne({
      where: { kycStatus: def.kycStatus },
    });
    if (!existing) {
      await models.TontineKycLimit.create(def);
    }
  }
}

async function listTontineKycLimits() {
  await ensureDefaultLimits();
  const limits = await models.TontineKycLimit.findAll({
    order: [
      sequelize.literal(
        "CASE kyc_status WHEN 'unverified' THEN 1 WHEN 'pending_review' THEN 2 WHEN 'verified' THEN 3 ELSE 4 END",
      ),
    ],
  });
  return limits.map((item) => ({
    id: item.id,
    kycStatus: item.kycStatus,
    tierLevel: item.tierLevel,
    label: item.label,
    description: item.description,
    maxDailyStake: Number(item.maxDailyStake),
    maxCycleCumulative: Number(item.maxCycleCumulative),
    allowMultipleCycles: Boolean(item.allowMultipleCycles),
    enabled: Boolean(item.enabled),
    updatedAt: item.updatedAt,
    updatedBy: item.updatedBy,
  }));
}

async function updateTontineKycLimits(updates = [], adminContext = {}) {
  if (!Array.isArray(updates) || updates.length === 0) {
    throw new AppError('Liste de mise à jour des plafonds invalide.', 422);
  }

  await ensureDefaultLimits();

  const updatedItems = [];

  await sequelize.transaction(async (transaction) => {
    for (const update of updates) {
      const kycStatus = String(update.kycStatus || '').trim().toLowerCase();
      if (!['unverified', 'pending_review', 'verified'].includes(kycStatus)) {
        continue;
      }

      const limitRecord = await models.TontineKycLimit.findOne({
        where: { kycStatus },
        transaction,
      });

      if (!limitRecord) {
        continue;
      }

      const maxDailyStake = update.maxDailyStake != null
        ? Math.max(Number(update.maxDailyStake), 0)
        : Number(limitRecord.maxDailyStake);

      const maxCycleCumulative = update.maxCycleCumulative != null
        ? Math.max(Number(update.maxCycleCumulative), 0)
        : Number(limitRecord.maxCycleCumulative);

      const allowMultipleCycles = update.allowMultipleCycles != null
        ? Boolean(update.allowMultipleCycles)
        : limitRecord.allowMultipleCycles;

      const enabled = update.enabled != null
        ? Boolean(update.enabled)
        : limitRecord.enabled;

      const label = update.label != null && String(update.label).trim()
        ? String(update.label).trim()
        : limitRecord.label;

      const description = update.description != null
        ? String(update.description).trim()
        : limitRecord.description;

      await limitRecord.update(
        {
          label,
          description,
          maxDailyStake,
          maxCycleCumulative,
          allowMultipleCycles,
          enabled,
          updatedBy: adminContext.adminUsername || 'admin',
        },
        { transaction },
      );

      updatedItems.push(limitRecord);
    }
  });

  await writeAuditLog({
    userId: null,
    action: 'tontine_kyc_limits.updated',
    entityType: 'tontineKycLimit',
    entityId: 'global',
    ipAddress: adminContext.ipAddress,
    userAgent: adminContext.userAgent,
    metadata: {
      adminUsername: adminContext.adminUsername || null,
      updatedCount: updatedItems.length,
      updates,
    },
  });

  return listTontineKycLimits();
}

async function getUserEffectiveKycLimit(userId, transaction) {
  await ensureDefaultLimits();

  const kycCase = await models.KycCase.findOne({
    where: { userId },
    transaction,
  });

  let effectiveStatus = 'unverified';
  if (kycCase) {
    const isExpired = kycCase.expiresAt && new Date(kycCase.expiresAt) < new Date();
    if (kycCase.status === 'verified' && !isExpired) {
      effectiveStatus = 'verified';
    } else if (kycCase.status === 'pending_review') {
      effectiveStatus = 'pending_review';
    }
  }

  const limitRecord = await models.TontineKycLimit.findOne({
    where: { kycStatus: effectiveStatus, enabled: true },
    transaction,
  });

  const fallback = DEFAULT_KYC_LIMITS.find((item) => item.kycStatus === effectiveStatus) ||
    DEFAULT_KYC_LIMITS[0];

  return {
    kycStatus: effectiveStatus,
    tierLevel: limitRecord?.tierLevel || fallback.tierLevel,
    label: limitRecord?.label || fallback.label,
    description: limitRecord?.description || fallback.description,
    maxDailyStake: Number(limitRecord?.maxDailyStake ?? fallback.maxDailyStake),
    maxCycleCumulative: Number(limitRecord?.maxCycleCumulative ?? fallback.maxCycleCumulative),
    allowMultipleCycles: Boolean(limitRecord?.allowMultipleCycles ?? fallback.allowMultipleCycles),
    isVerified: effectiveStatus === 'verified',
  };
}

module.exports = {
  DEFAULT_KYC_LIMITS,
  ensureDefaultLimits,
  listTontineKycLimits,
  updateTontineKycLimits,
  getUserEffectiveKycLimit,
};
