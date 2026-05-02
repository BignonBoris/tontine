const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

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
    endDate: payload.endDate,
    startDate: payload.startDate || new Date(),
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
    if (nextAmount >= Number(goal.targetAmount)) {
      await models.Notification.create(
        {
          userId,
          type: 'goal',
          title: 'Objectif atteint',
          message: `Le coffre ${goal.title} a atteint son objectif.`,
        },
        { transaction },
      );
    }

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
    await wallet.update(
      {
        availableBalance:
          Number(wallet.availableBalance) + Number(goal.currentAmount),
      },
      { transaction },
    );
    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'goalFunding',
        amount: goal.currentAmount,
        label: `Cloture coffre ${goal.title}`,
        isCredit: true,
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
        returnedAmount: Number(goal.currentAmount),
      },
      transaction,
    });
    return getGoal(userId, goalId);
  });
}

async function depositGoalDirectly(userId, goalId, amount, requestContext = {}) {
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

    const remainingAmount = Number(goal.targetAmount) - Number(goal.currentAmount);
    if (remainingAmount <= 0) {
      throw new AppError('Ce coffre a deja atteint son objectif.', 409);
    }
    if (amount > remainingAmount) {
      throw new AppError("Le montant depasse l'objectif restant.", 422);
    }

    const nextAmount = Number(goal.currentAmount) + amount;
    await goal.update({ currentAmount: nextAmount }, { transaction });
    await models.GoalTransaction.create(
      {
        goalId: goal.id,
        title: 'Depot',
        amount,
        isDeposit: true,
      },
      { transaction },
    );

    await writeAuditLog({
      userId,
      action: 'goal.directDeposit',
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

module.exports = {
  listGoals,
  getGoal,
  createGoal,
  fundGoal,
  closeGoal,
  depositGoalDirectly,
};
