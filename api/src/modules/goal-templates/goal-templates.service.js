const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

const MAX_TEMPLATES_PER_ONBOARDING = 3;
// Montant objectif de repli lorsqu'un modele n'en definit pas (FCFA).
const DEFAULT_FALLBACK_TARGET_AMOUNT = 1000;

function addMonthsPreservingDay(date, monthsToAdd) {
  const source = new Date(date);
  const targetMonthIndex = source.getMonth() + monthsToAdd;
  const lastDayOfTargetMonth = new Date(
    source.getFullYear(),
    targetMonthIndex + 1,
    0,
  ).getDate();

  return new Date(
    source.getFullYear(),
    targetMonthIndex,
    Math.min(source.getDate(), lastDayOfTargetMonth),
    source.getHours(),
    source.getMinutes(),
    source.getSeconds(),
    source.getMilliseconds(),
  );
}

/**
 * Liste des modeles actifs pour le mobile + statut d'onboarding du client.
 */
async function listActiveTemplates(userId) {
  const [templates, preference] = await Promise.all([
    models.GoalTemplate.findAll({
      where: { isActive: true },
      order: [
        ['sortOrder', 'ASC'],
        ['label', 'ASC'],
      ],
    }),
    models.UserPreference.findOne({
      where: { userId },
      attributes: ['onboardingGoalsDone'],
    }),
  ]);

  return {
    templates,
    onboardingCompleted: Boolean(preference?.onboardingGoalsDone),
  };
}

async function listAllTemplates() {
  return models.GoalTemplate.findAll({
    order: [
      ['sortOrder', 'ASC'],
      ['label', 'ASC'],
    ],
  });
}

function validateTemplatePayload(payload = {}) {
  const label = String(payload.label || '').trim();
  if (label.length < 3) {
    throw new AppError('Le libelle du coffre par defaut est invalide.', 422);
  }

  const iconCodePoint = Number(payload.iconCodePoint);
  if (!Number.isInteger(iconCodePoint) || iconCodePoint <= 0) {
    throw new AppError("L'icone du coffre par defaut est invalide.", 422);
  }

  const colorValue = Number(payload.colorValue);
  if (!Number.isFinite(colorValue) || colorValue < 0) {
    throw new AppError('La couleur du coffre par defaut est invalide.', 422);
  }

  const sortOrder = payload.sortOrder == null ? 0 : Number(payload.sortOrder);
  if (!Number.isInteger(sortOrder) || sortOrder < 0) {
    throw new AppError("L'ordre d'affichage du coffre est invalide.", 422);
  }

  let defaultTargetAmount = null;
  if (payload.defaultTargetAmount != null) {
    defaultTargetAmount = Number(payload.defaultTargetAmount);
    if (!Number.isFinite(defaultTargetAmount) || defaultTargetAmount <= 0) {
      throw new AppError('Le montant objectif par defaut est invalide.', 422);
    }
  }

  const description = payload.description
    ? String(payload.description).trim().slice(0, 255)
    : null;

  return {
    label,
    description,
    iconCodePoint,
    colorValue,
    sortOrder,
    defaultTargetAmount,
  };
}

async function createTemplate(payload, adminId = null, requestContext = {}) {
  const values = validateTemplatePayload(payload);
  const template = await models.GoalTemplate.create(values);

  await writeAuditLog({
    userId: null,
    action: 'goal_template.created',
    entityType: 'goal_template',
    entityId: template.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: { adminId, label: template.label },
  });

  return template;
}

async function updateTemplate(id, payload, adminId = null, requestContext = {}) {
  const template = await models.GoalTemplate.findByPk(id);
  if (!template) {
    throw new AppError('Coffre par defaut introuvable.', 404);
  }

  const values = validateTemplatePayload({
    label: payload.label ?? template.label,
    description: payload.description ?? template.description,
    iconCodePoint: payload.iconCodePoint ?? template.iconCodePoint,
    colorValue: payload.colorValue ?? template.colorValue,
    sortOrder: payload.sortOrder ?? template.sortOrder,
    defaultTargetAmount:
      payload.defaultTargetAmount ?? template.defaultTargetAmount,
  });

  await template.update({
    ...values,
    isActive:
      payload.isActive == null ? template.isActive : Boolean(payload.isActive),
  });

  await writeAuditLog({
    userId: null,
    action: 'goal_template.updated',
    entityType: 'goal_template',
    entityId: template.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: { adminId, label: template.label },
  });

  return template;
}

async function deleteTemplate(id, adminId = null, requestContext = {}) {
  const template = await models.GoalTemplate.findByPk(id);
  if (!template) {
    throw new AppError('Coffre par defaut introuvable.', 404);
  }

  await template.destroy();

  await writeAuditLog({
    userId: null,
    action: 'goal_template.deleted',
    entityType: 'goal_template',
    entityId: id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: { adminId, label: template.label },
  });

  return { id };
}

/**
 * Onboarding : transforme la selection du client (1 a 3 modeles) en coffres
 * reels. Contourne volontairement les regles classiques de creation de coffre
 * (tontine active, 1 coffre/mois) : un tout nouveau client n'a ni l'un ni
 * l'autre — c'est le seul flux autorise a creer plusieurs coffres d'un coup.
 */
async function applyTemplates(userId, templateIds, requestContext = {}) {
  if (!Array.isArray(templateIds)) {
    throw new AppError('La selection de coffres est invalide.', 422);
  }

  const uniqueIds = [
    ...new Set(templateIds.map((id) => String(id).trim()).filter(Boolean)),
  ];
  if (uniqueIds.length < 1) {
    throw new AppError('Selectionnez au moins un coffre pour demarrer.', 422);
  }
  if (uniqueIds.length > MAX_TEMPLATES_PER_ONBOARDING) {
    throw new AppError(
      `Vous pouvez selectionner au maximum ${MAX_TEMPLATES_PER_ONBOARDING} coffres.`,
      422,
    );
  }

  return sequelize.transaction(async (transaction) => {
    const [preference, templates] = await Promise.all([
      models.UserPreference.findOne({ where: { userId }, transaction }),
      models.GoalTemplate.findAll({
        where: { id: uniqueIds, isActive: true },
        transaction,
      }),
    ]);

    if (preference?.onboardingGoalsDone) {
      throw new AppError('Vos coffres de demarrage sont deja configures.', 409);
    }

    if (templates.length !== uniqueIds.length) {
      throw new AppError(
        'Un ou plusieurs coffres selectionnes ne sont plus disponibles.',
        404,
      );
    }

    const now = new Date();
    const endDate = addMonthsPreservingDay(now, 12);
    const createdGoals = [];

    for (const template of templates) {
      const goal = await models.Goal.create(
        {
          userId,
          title: template.label,
          targetAmount:
            template.defaultTargetAmount ?? DEFAULT_FALLBACK_TARGET_AMOUNT,
          currentAmount: 0,
          iconCodePoint: template.iconCodePoint,
          colorValue: template.colorValue,
          startDate: now,
          endDate,
        },
        { transaction },
      );
      createdGoals.push(goal);

      await writeAuditLog({
        userId,
        action: 'goal.created_from_template',
        entityType: 'goal',
        entityId: goal.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          templateId: template.id,
          templateLabel: template.label,
        },
        transaction,
      });
    }

    await models.UserPreference.findOrCreate({
      where: { userId },
      defaults: { userId },
      transaction,
    });
    await models.UserPreference.update(
      { onboardingGoalsDone: true },
      { where: { userId }, transaction },
    );

    await writeAuditLog({
      userId,
      action: 'onboarding.goals_applied',
      entityType: 'user',
      entityId: userId,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        templateIds: templates.map((template) => template.id),
        createdCount: createdGoals.length,
      },
      transaction,
    });

    return { createdCount: createdGoals.length, goals: createdGoals };
  });
}

module.exports = {
  listActiveTemplates,
  listAllTemplates,
  createTemplate,
  updateTemplate,
  deleteTemplate,
  applyTemplates,
  MAX_TEMPLATES_PER_ONBOARDING,
};
