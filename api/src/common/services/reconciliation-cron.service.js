const { Op } = require('sequelize');
const Sentry = require('@sentry/node');
const { models } = require('../../database/models');
const { writeAuditLog } = require('./audit-log.service');
const { runReconciliation } = require('../../modules/admin/admin-reconciliation.service');
const { reconcileFedapayIntent } = require('../../modules/tontine/tontine-fedapay.service');
const { reconcileMtnMomoIntent } = require('../../modules/tontine/tontine-mtnmomo.service');
const { reconcileAfrikmoneyIntent } = require('../../modules/tontine/tontine-afrikmoney.service');

// Intervalle par défaut : 6 heures (ou variable d'environnement)
const INTERVAL_MS = Number(process.env.RECONCILIATION_CRON_INTERVAL_MS) || 6 * 60 * 60 * 1000;
let cronTimer = null;
let isReconciliationRunning = false;

/**
 * Réconcilie automatiquement les intents de paiement mobiles/webhooks restés en pending.
 */
async function reconcilePendingPaymentIntents() {
  const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
  const pendingIntents = await models.TontinePaymentIntent.findAll({
    where: {
      status: 'pending',
      createdAt: { [Op.lte]: fifteenMinutesAgo },
    },
    limit: 25,
    order: [['createdAt', 'ASC']],
  });

  if (!pendingIntents.length) {
    return { reconciled: 0 };
  }

  console.log(`[RECONCILIATION_CRON] Vérification de ${pendingIntents.length} paiement(s) en attente...`);

  let processedCount = 0;
  for (const intent of pendingIntents) {
    try {
      if (intent.provider === 'fedapay') {
        await reconcileFedapayIntent(intent, { initiatorType: 'cron' });
      } else if (intent.provider === 'mtn_momo') {
        await reconcileMtnMomoIntent(intent, { initiatorType: 'cron' });
      } else if (intent.provider === 'afrikmoney') {
        await reconcileAfrikmoneyIntent(intent, { initiatorType: 'cron' });
      }
      processedCount++;
    } catch (err) {
      console.warn(`[RECONCILIATION_CRON] Échec réconciliation intent ${intent.id} (${intent.provider}):`, err.message);
    }
  }

  return { reconciled: processedCount };
}

/**
 * Exécute un cycle complet de réconciliation bancaire et de cantonnement.
 */
async function executeReconciliationCycle() {
  if (isReconciliationRunning) {
    console.log('[RECONCILIATION_CRON] Cycle déjà en cours, saut de cette itération.');
    return;
  }

  isReconciliationRunning = true;
  console.log('[RECONCILIATION_CRON] ── Démarrage du cycle de réconciliation financière ──');

  try {
    // 1. Réconciliation des flux passerelles de paiement
    const intentResult = await reconcilePendingPaymentIntents();

    // 2. Audit global du cantonnement (Passifs vs Caisse Agents vs Réserve requise)
    const report = await runReconciliation();

    console.log(
      `[RECONCILIATION_CRON] Résultat : Total Passifs = ${report.totalLiabilities} F | ` +
      `Caisse Agents = ${report.assets.agentCash} F | ` +
      `Réserve Bancaire Requise = ${report.requiredBankReserve} F | ` +
      `Santé = ${report.isHealthy ? '✅ SAINE' : '🚨 ANOMALIE DE CANTONNEMENT'}`
    );

    // 3. Log d'audit de conformité
    await writeAuditLog({
      action: 'system.reconciliation_cycle',
      entityType: 'financial_reconciliation',
      entityId: report.timestamp.toISOString(),
      metadata: {
        totalLiabilities: report.totalLiabilities,
        agentCash: report.assets.agentCash,
        requiredBankReserve: report.requiredBankReserve,
        isHealthy: report.isHealthy,
        reconciledPendingIntents: intentResult.reconciled,
      },
    });

    // 4. Alerte immédiate si déficit ou anomalie
    if (!report.isHealthy) {
      const alertMessage = `🚨 ALERTE CRITIQUE : Déficit de cantonnement bancaire détecté ! Réserve requise négative (${report.requiredBankReserve} F)`;
      console.error(alertMessage);
      Sentry.captureMessage(alertMessage, {
        level: 'fatal',
        extra: report,
      });
    }

    return report;
  } catch (error) {
    console.error('[RECONCILIATION_CRON] Erreur durant la réconciliation:', error);
    Sentry.captureException(error);
  } finally {
    isReconciliationRunning = false;
  }
}

/**
 * Démarre le planificateur de réconciliation.
 */
function startReconciliationCron() {
  if (cronTimer) {
    return;
  }

  console.log(`[RECONCILIATION_CRON] Service initialisé (Fréquence: ${INTERVAL_MS / 3600000}h)`);

  // Premier audit différé de 15 secondes après démarrage
  setTimeout(() => {
    executeReconciliationCycle().catch((err) => {
      console.error('[RECONCILIATION_CRON] Erreur exécution initiale:', err.message);
    });
  }, 15000);

  // Intervalle régulier
  cronTimer = setInterval(() => {
    executeReconciliationCycle().catch((err) => {
      console.error('[RECONCILIATION_CRON] Erreur exécution périodique:', err.message);
    });
  }, INTERVAL_MS);
}

/**
 * Arrête le planificateur proprement (utile pour tests / shutdown).
 */
function stopReconciliationCron() {
  if (cronTimer) {
    clearInterval(cronTimer);
    cronTimer = null;
    console.log('[RECONCILIATION_CRON] Service arrêté.');
  }
}

module.exports = {
  startReconciliationCron,
  stopReconciliationCron,
  executeReconciliationCycle,
  reconcilePendingPaymentIntents,
};
