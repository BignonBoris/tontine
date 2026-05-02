const { Op } = require('sequelize');
const AppError = require('../../common/errors/app-error');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');

const marketOrderLabels = {
  pending: 'En attente',
  confirmed: 'Confirmee',
  ready: 'Prete',
  completed: 'Livree',
  cancelled: 'Annulee',
};

function nextOrderStatus(status) {
  switch (status) {
    case 'pending':
      return 'confirmed';
    case 'confirmed':
      return 'ready';
    case 'ready':
      return 'completed';
    default:
      return status;
  }
}

async function listOffers({ search, category }) {
  const where = { isActive: true };
  if (category) {
    where.category = category;
  }
  if (search) {
    where[Op.or] = [
      { title: { [Op.like]: `%${search}%` } },
      { description: { [Op.like]: `%${search}%` } },
      { brand: { [Op.like]: `%${search}%` } },
      { category: { [Op.like]: `%${search}%` } },
    ];
  }
  return models.MarketOffer.findAll({ where, order: [['createdAt', 'DESC']] });
}

async function listFavorites(userId) {
  const favorites = await models.MarketFavorite.findAll({
    where: { userId },
    include: [{ model: models.MarketOffer, as: 'offer' }],
    order: [['createdAt', 'DESC']],
  });
  return favorites.map((favorite) => favorite.offer);
}

async function toggleFavorite(userId, offerId) {
  const offer = await models.MarketOffer.findByPk(offerId);
  if (!offer) {
    throw new AppError('Article introuvable.', 404);
  }

  const favorite = await models.MarketFavorite.findOne({ where: { userId, offerId } });
  if (favorite) {
    await favorite.destroy();
    return { isFavorite: false };
  }

  await models.MarketFavorite.create({ userId, offerId });
  return { isFavorite: true };
}

async function listOrders(userId) {
  return models.MarketOrder.findAll({
    where: { userId },
    order: [['orderedAt', 'DESC']],
  });
}

async function createOrder(userId, offerId, quantity = 1, requestContext = {}) {
  if (!Number.isInteger(quantity) || quantity <= 0) {
    throw new AppError('La quantite doit etre un entier positif.', 422);
  }

  return sequelize.transaction(async (transaction) => {
    const offer = await models.MarketOffer.findByPk(offerId, { transaction });
    if (!offer || !offer.isActive) {
      throw new AppError('Article introuvable.', 404);
    }

    const unitPrice = Number(offer.price || 0);
    const totalAmount = unitPrice * quantity;
    if (totalAmount <= 0) {
      throw new AppError('Montant de commande invalide.', 422);
    }
    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    if (Number(wallet.availableBalance) < totalAmount) {
      throw new AppError('Solde disponible insuffisant.', 422);
    }

    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) - totalAmount,
      },
      { transaction },
    );
    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'goalFunding',
        amount: totalAmount,
        label: `Achat ${offer.title} x${quantity}`,
        isCredit: false,
      },
      { transaction },
    );
    const order = await models.MarketOrder.create(
      {
        userId,
        offerId,
        title: offer.title,
        amount: totalAmount,
        quantity,
        unitPrice,
        status: 'pending',
      },
      { transaction },
    );
    await models.Notification.create(
      {
        userId,
        type: 'marketplace',
        title: 'Commande creee',
        message: `L'achat de ${offer.title} x${quantity} est en attente de traitement.`,
      },
      { transaction },
    );
    await writeAuditLog({
      userId,
      action: 'marketplace.orderCreated',
      entityType: 'marketOrder',
      entityId: order.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        offerId,
        quantity,
        unitPrice,
        totalAmount,
      },
      transaction,
    });
    return order;
  });
}

async function advanceOrder(userId, orderId, requestContext = {}) {
  const order = await models.MarketOrder.findOne({ where: { id: orderId, userId } });
  if (!order) {
    throw new AppError('Commande introuvable.', 404);
  }
  if (!['pending', 'confirmed', 'ready'].includes(order.status)) {
    throw new AppError('Cette commande ne peut plus avancer.', 409);
  }

  const next = nextOrderStatus(order.status);
  await order.update({ status: next, updatedStatusAt: new Date() });
  await models.Notification.create({
    userId,
    type: 'marketplace',
    title: 'Commande mise a jour',
    message: `${order.title} est maintenant ${marketOrderLabels[next].toLowerCase()}.`,
  });
  await writeAuditLog({
    userId,
    action: 'marketplace.orderAdvanced',
    entityType: 'marketOrder',
    entityId: order.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      nextStatus: next,
    },
  });
  return order;
}

async function cancelOrder(userId, orderId, requestContext = {}) {
  return sequelize.transaction(async (transaction) => {
    const order = await models.MarketOrder.findOne({
      where: { id: orderId, userId },
      transaction,
    });
    if (!order) {
      throw new AppError('Commande introuvable.', 404);
    }
    if (!['pending', 'confirmed'].includes(order.status)) {
      throw new AppError("Cette commande n'est plus annulable.", 409);
    }

    const wallet = await models.Wallet.findOne({ where: { userId }, transaction });
    await wallet.update(
      {
        availableBalance: Number(wallet.availableBalance) + Number(order.amount),
      },
      { transaction },
    );
    await models.AvailableBalanceHistory.create(
      {
        userId,
        type: 'tontinePayout',
        amount: order.amount,
        label: `Remboursement commande ${order.title}`,
        isCredit: true,
      },
      { transaction },
    );
    await order.update(
      {
        status: 'cancelled',
        updatedStatusAt: new Date(),
      },
      { transaction },
    );
    await models.Notification.create(
      {
        userId,
        type: 'marketplace',
        title: 'Commande annulee',
        message: `${Number(order.amount)} F ont ete rembourses pour ${order.title}.`,
      },
      { transaction },
    );
    await writeAuditLog({
      userId,
      action: 'marketplace.orderCancelled',
      entityType: 'marketOrder',
      entityId: order.id,
      ipAddress: requestContext.ipAddress,
      userAgent: requestContext.userAgent,
      metadata: {
        refundedAmount: Number(order.amount),
      },
      transaction,
    });
    return order;
  });
}

module.exports = {
  listOffers,
  listFavorites,
  toggleFavorite,
  listOrders,
  createOrder,
  advanceOrder,
  cancelOrder,
};
