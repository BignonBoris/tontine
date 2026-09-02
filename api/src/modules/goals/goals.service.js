const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { getUserEffectiveKycLimit } = require('../tontine/tontine.service');

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

async function validateGoalCreationRules(userId, targetAmount, endDate) {
  const now = new Date();

  const [lastGoal, activeCycle, wallet] = await Promise.all([
    models.Goal.findOne({
      where: { userId },
      order: [['createdAt', 'DESC']],
    }),
    models.TontineCycle.findOne({
      where: { userId, status: 'active' },
      order: [['createdAt', 'DESC']],
    }),
    models.Wallet.findOne({
      where: { userId },
    }),
  ]);

  if (lastGoal) {
    const nextAllowedAt = addMonthsPreservingDay(lastGoal.createdAt, 1);
    if (now < nextAllowedAt) {
      throw new AppError(
        `Vous pourrez creer un nouveau coffre a partir du ${nextAllowedAt.toLocaleDateString('fr-FR')}.`,
        409,
        { nextAllowedAt: nextAllowedAt.toISOString() },
      );
    }
  }

  if (!activeCycle) {
    throw new AppError(
      'Vous devez avoir une tontine active pour creer un coffre.',
      409,
    );
  }

  if (!wallet) {
    throw new AppError('Portefeuille introuvable.', 404);
  }

  if (!(endDate instanceof Date) || Number.isNaN(endDate.getTime())) {
    throw new AppError("La date d'echeance du coffre est invalide.", 422);
  }

  if (endDate <= now) {
    throw new AppError(
      "La date d'echeance du coffre doit etre posterieure a aujourd'hui.",
      422,
    );
  }

  const maxEndDate = addMonthsPreservingDay(now, 12);
  if (endDate > maxEndDate) {
    throw new AppError(
      "La date d'echeance du coffre ne peut pas depasser un an.",
      422,
    );
  }

  const maxTargetAmount =
    Number(activeCycle.stakeAmount) * 30 * 12 + Number(wallet.availableBalance);

  if (targetAmount > maxTargetAmount) {
    throw new AppError(
      `L'objectif du coffre ne peut pas depasser ${maxTargetAmount.toFixed(2)} F CFA pour votre profil actuel.`,
      422,
      { maxTargetAmount },
    );
  }

  // Vérification de la limite KYC
  const kycLimit = await getUserEffectiveKycLimit(userId);
  if (kycLimit && kycLimit.maxVaultCumulative) {
    const totalExistingGoals = await models.Goal.sum('targetAmount', {
      where: { userId, status: 'active' },
    }) || 0;

    const projectedTotal = Number(totalExistingGoals) + targetAmount;
    if (projectedTotal > Number(kycLimit.maxVaultCumulative)) {
      throw new AppError(
        `Votre niveau de vérification plafonne le cumul de vos coffres à ${Number(kycLimit.maxVaultCumulative)} F CFA.`,
        403,
      );
    }
  }

  return { activeCycle, wallet, now };
}

async function listGoals(userId) {
  return models.Goal.findAll({
    where: { userId },
    include: [{ model: models.GoalTransaction, as: 'transactions' }],
    order: [['createdAt', 'DESC']],
  });
}

async function getGoal(userId, goalId) {
  const goal = await models.Goal.findOne({
    where: { id: goalId, userId },
    include: [{ model: models.GoalTransaction, as: 'transactions' }],
  });
  if (!goal) {
    throw new AppError('Coffre introuvable.', 404);
  }
  return goal;
}

async function createGoal(userId, payload, requestContext = {}) {
  const quantity = Number(payload.quantity || 1);
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new AppError('La quantite doit etre un entier positif.', 422);
  }

  const title = String(payload.title || '').trim();
  const unitPrice = payload.unitPrice == null ? null : Number(payload.unitPrice);
  const targetAmount = Number(payload.targetAmount);
  const linkedOfferId = payload.linkedOfferId || null;

  if (title.length < 3) {
    throw new AppError('Le titre du coffre est invalide.', 422);
  }

  if (!targetAmount || targetAmount <= 0) {
    throw new AppError("L'objectif du coffre est invalide.", 422);
  }

  const endDate = new Date(payload.endDate);
  const { now } = await validateGoalCreationRules(userId, targetAmount, endDate);

  if (linkedOfferId) {
    const existingGoal = await models.Goal.findOne({
      where: {
        userId,
        linkedOfferId,
        status: 'active',
      },
    });

    if (existingGoal) {
      throw new AppError(
        'Un coffre actif existe deja pour cet article.',
        409,
      );
    }
  }

  const goal = await models.Goal.create({
    userId,
    linkedOfferId,
    quantity,
    unitPrice,
    title,
    targetAmount,
    currentAmount: 0,
    iconCodePoint: payload.iconCodePoint,
    colorValue: payload.colorValue,
    endDate,
    startDate: now,
  });

  await writeAuditLog({
    userId,
    action: 'goal.created',
    entityType: 'goal',
    entityId: goal.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      linkedOfferId,
      quantity,
      targetAmount,
    },
  });

  return goal;
}

async function fundGoal(userId, goalId, amount, requestContext = {}) {
  if (!amount || amount <= 0) {
    throw new AppError('Montant invalide.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    const goal = await models.Goal.findOne({
      where: { id: goalId, userId },
      transaction,
    });
    if (!goal) {
      throw new AppError('Coffre introuvable.', 404);
    }
    if (goal.status !== 'active') {
      throw new AppError("Ce coffre n'est plus actif.", 409);
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    if (Number(wallet.availableBalance) < amount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    const remainingAmount = Number(goal.targetAmount) - Number(goal.currentAmount);
    if (remainingAmount <= 0) {
      throw new AppError('Ce coffre a deja atteint son objectif.', 409);
    }
    if (amount > remainingAmount) {
      throw new AppError("Le montant depasse l'objectif restant.", 422);
    }

    const nextAmount = Number(goal.currentAmount) + amount;

    await wallet.update(
      { availableBalance: Number(wallet.availableBalance) - amount },
      { transaction },
    );
    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'goalFunding',
        amount,
        label: `Vers coffre ${goal.title}`,
        isCredit: false,
      },
      { transaction },
    );
    await goal.update({ currentAmount: nextAmount }, { transaction });
    await models.GoalTransaction.create(
      {
        goalId: goal.id,
        title: 'Epargne depuis disponible',
        amount,
        isDeposit: true,
      },
      { transaction },
    );

    const targetAmount = Number(goal.targetAmount);
    const isGoalReached = nextAmount >= targetAmount;
    await models.Notification.create(
      {
        userId,
        type: 'goal',
        title: isGoalReached ? 'Objectif atteint' : 'Coffre alimente',
        message: isGoalReached
          ? `Votre coffre ${goal.title} a recu ${Number(amount).toFixed(0)} F et a atteint ${Number(nextAmount).toFixed(0)} F sur ${targetAmount.toFixed(0)} F.`
          : `Votre coffre ${goal.title} a recu ${Number(amount).toFixed(0)} F. Progression: ${Number(nextAmount).toFixed(0)} F sur ${targetAmount.toFixed(0)} F.`,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'goal.funded',
      entityType: 'goal',
      entityId: goal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        amount,
        nextAmount,
      },
      transaction,
    });

    return getGoal(userId, goalId);
  });
}

async function getGoalConfig() {
  const penaltySetting = await models.SystemSetting.findOne({
    where: { key: 'GOAL_EARLY_CLOSURE_PENALTY_PERCENT' },
  });
  
  return {
    earlyClosurePenaltyPercent: penaltySetting ? Number(penaltySetting.value) : 5.0,
  };
}

async function closeGoal(userId, goalId, requestContext = {}) {
  return sequelize.transaction(async (transaction) => {
    const goal = await models.Goal.findOne({
      where: { id: goalId, userId },
      transaction,
    });
    if (!goal) {
      throw new AppError('Coffre introuvable.', 404);
    }
    if (goal.status !== 'active') {
      throw new AppError('Ce coffre est deja cloture.', 409);
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    const now = new Date();
    const isEarlyClosure = now < goal.endDate;
    
    let penaltyAmount = 0;
    let penaltyPercent = 0;
    
    if (isEarlyClosure) {
      const penaltySetting = await models.SystemSetting.findOne({
        where: { key: 'GOAL_EARLY_CLOSURE_PENALTY_PERCENT' },
        transaction,
      });
      penaltyPercent = penaltySetting ? Number(penaltySetting.value) : 5.0;
      penaltyAmount = (Number(goal.currentAmount) * penaltyPercent) / 100;
    }

    const returnedAmount = Number(goal.currentAmount) - penaltyAmount;

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) + returnedAmount,
      },
      { transaction },
    );
    
    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'goalFunding',
        amount: returnedAmount,
        label: `Cloture coffre ${goal.title}`,
        isCredit: true,
      },
      { transaction },
    );
    
    if (penaltyAmount > 0) {
      // Trace de la pénalité conservée
      await models.AvailableBalanceHistory.create(
        {
          userId,
          type: 'adjustment',
          amount: penaltyAmount,
          label: `Penalite cloture anticipee coffre ${goal.title} (${penaltyPercent}%)`,
          isCredit: false,
        },
        { transaction },
      );
    }

    await models.Notification.create(
      {
        userId,
        type: 'goal',
        title: 'Coffre cloture',
        message: penaltyAmount > 0 
            ? `${returnedAmount.toFixed(0)} F reverses sur votre solde pour le coffre ${goal.title} (Penalite: ${penaltyAmount.toFixed(0)} F).`
            : `${returnedAmount.toFixed(0)} F reverses sur votre solde disponible pour le coffre ${goal.title}.`,
      },
      { transaction },
    );
    await goal.update({ status: 'closed' }, { transaction });
    await writeAuditLog({
      userId,
      action: 'goal.closed',
      entityType: 'goal',
      entityId: goal.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        totalAmount: Number(goal.currentAmount),
        returnedAmount,
        penaltyAmount,
        penaltyPercent,
        isEarlyClosure,
      },
      transaction,
    });
    return getGoal(userId, goalId);
  });
}

module.exports = {
  listGoals,
  getGoalConfig,
  getGoal,
  createGoal,
  fundGoal,
  closeGoal,
};
