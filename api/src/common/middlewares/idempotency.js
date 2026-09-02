const { models } = require('../../database/models');
const { badRequest, conflict } = require('../utils/api-response');
const { Op } = require('sequelize');

/**
 * Middleware d'idempotence pour éviter les doublons de traitement (R-02)
 * @param {Object} options - Options de configuration (ex: { ttl: 24 })
 */
const idempotency = (options = {}) => {
  const ttlHours = options.ttl || 24;

  return async (req, res, next) => {
    const idempotencyKey = req.header('Idempotency-Key');

    // Si aucune clé n'est fournie, on laisse passer (ou on pourrait exiger la clé)
    // Selon la spécification, on devrait exiger l'idempotence pour les paiements
    if (!idempotencyKey) {
      return badRequest(res, 'Le header Idempotency-Key est obligatoire pour cette operation.');
    }

    try {
      const existingKey = await models.IdempotencyKey.findOne({
        where: { key: idempotencyKey },
      });

      if (existingKey) {
        if (existingKey.status === 'COMPLETED') {
          // Si déjà traité, on renvoie la réponse mise en cache
          const responseBody = existingKey.responseBody || { message: 'Operation deja effectuee.' };
          return res.status(existingKey.responseCode || 200).json(responseBody);
        } else if (existingKey.status === 'PROCESSING') {
          // Si en cours, on retourne un conflit (409)
          return conflict(res, 'Une operation avec cette cle est deja en cours de traitement.');
        } else {
          // Si ERROR, on pourrait permettre de réessayer, donc on le supprime
          await existingKey.destroy();
        }
      }

      // Création de l'enregistrement "PROCESSING"
      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + ttlHours);

      const idempotencyRecord = await models.IdempotencyKey.create({
        key: idempotencyKey,
        path: req.originalUrl,
        userId: req.auth ? req.auth.userId : null,
        requestBody: req.body,
        status: 'PROCESSING',
        expiresAt,
      });

      // On intercepte la méthode res.json pour sauvegarder la réponse
      const originalJson = res.json;
      res.json = function (body) {
        // Enregistrer asynchrone la réponse sans bloquer le renvoi
        const statusCode = res.statusCode;
        const status = (statusCode >= 200 && statusCode < 300) ? 'COMPLETED' : 'ERROR';
        
        idempotencyRecord.update({
          responseBody: body,
          responseCode: statusCode,
          status,
        }).catch(err => console.error('Erreur lors de la mise a jour de la cle d idempotence:', err));

        // Appeler la méthode originale
        originalJson.call(this, body);
      };

      next();
    } catch (error) {
      console.error('Erreur dans le middleware idempotency:', error);
      next(error);
    }
  };
};

module.exports = idempotency;
