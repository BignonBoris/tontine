const crypto = require('crypto');
const AppError = require('../../common/errors/app-error');
const env = require('../../config/env');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const {
  getOpenCycleForFunding,
  depositToCycle,
} = require('./tontine.service');
const { FINANCIAL_AMOUNT_STEP } = require('../../common/constants/finance');

let Webhook;
try {
  ({ Webhook } = require('fedapay'));
} catch (_) {
  Webhook = null;
}

function normalizeAmount(amount) {
  const normalized = Number(amount);
  if (!Number.isFinite(normalized)) {
    return NaN;
  }
  return normalized;
}

function formatAmount(amount) {
  return Number(amount).toFixed(0);
}

function getFedapayBaseUrl() {
  return String(env.fedapayApiBaseUrl || '').replace(/\/+$/, '');
}

function getFedapaySecretKey() {
  const secretKey = String(env.fedapaySecretKey || '').trim();
  if (!secretKey) {
    throw new AppError('FedaPay n est pas configure sur le serveur.', 503);
  }
  return secretKey;
}

function getFedapayWebhookSecret() {
  const secret = String(env.fedapayWebhookSecret || '').trim();
  if (!secret) {
    throw new AppError(
      'Le secret de webhook FedaPay n est pas configure.',
      503,
    );
  }
  return secret;
}

function buildMerchantReference(intentId) {
  return `TT-${String(intentId || '').replace(/-/g, '').slice(0, 32)}`;
}

function buildReturnUrl(merchantReference) {
  const baseUrl = String(env.appBaseUrl || '').replace(/\/+$/, '');
  return `${baseUrl}/api/v1/tontine/fedapay/return?merchantReference=${encodeURIComponent(
    merchantReference,
  )}`;
}

function extractMessage(payload, fallbackMessage) {
  if (!payload) {
    return fallbackMessage;
  }
  if (typeof payload === 'string' && payload.trim()) {
    return payload.trim();
  }
  return (
    payload.message ||
    payload.error ||
    payload.detail ||
    payload.raw ||
    fallbackMessage
  );
}

async function parseJsonResponse(response) {
  const rawText = await response.text();
  if (!rawText) {
    return null;
  }

  try {
    return JSON.parse(rawText);
  } catch (_) {
    return { raw: rawText };
  }
}

function isLockWaitTimeoutError(error) {
  const message = String(error?.message || '');
  return (
    message.includes('Lock wait timeout exceeded') ||
    message.includes('ER_LOCK_WAIT_TIMEOUT') ||
    error?.original?.errno === 1205 ||
    error?.parent?.errno === 1205
  );
}

function buildWebhookReplayHeader(rawBody, secret = getFedapayWebhookSecret()) {
  const payload = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody || '');
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${payload}`, 'utf8')
    .digest('hex');

  return {
    timestamp,
    signature,
    header: `t=${timestamp},s=${signature}`,
    payload,
  };
}

async function requestFedapay(path, options = {}) {
  const url = `${getFedapayBaseUrl()}${path}`;

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${getFedapaySecretKey()}`,
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      },
    });

    const payload = await parseJsonResponse(response);
    if (!response.ok) {
      throw new AppError(
        extractMessage(payload, 'FedaPay a refuse la requete.'),
        502,
        payload,
      );
    }

    return unwrapFedapayResource(payload);
  } catch (error) {
    const cause =
      error?.cause?.code ||
      error?.cause?.message ||
      error?.message ||
      String(error);

    console.warn('[FedaPay] request failed', {
      url,
      cause,
    });

    if (error instanceof AppError) {
      throw error;
    }

    throw new AppError(
      `Impossible de joindre FedaPay (${url}). Verifiez FEDAPAY_API_BASE_URL, la connectivite sortante du serveur et le DNS.`,
      503,
      { cause, url },
    );
  }
}

function extractFedapayEventName(event) {
  return String(
    event?.name ||
    event?.event ||
    event?.type ||
    event?.data?.name ||
    event?.data?.type ||
    '',
  ).trim();
}

function extractFedapayTransaction(event) {
  const candidates = [
    event?.data?.object,
    event?.data,
    event?.object,
    event?.transaction,
    event?.payload?.data,
    event?.payload,
    event,
  ];

  for (const candidate of candidates) {
    if (candidate && typeof candidate === 'object') {
      return candidate;
    }
  }

  return null;
}

function extractMerchantReference(transaction) {
  const resource = unwrapFedapayResource(transaction);
  return String(
    resource?.merchant_reference ||
    resource?.merchantReference ||
    resource?.reference ||
    resource?.data?.merchant_reference ||
    resource?.data?.merchantReference ||
    resource?.data?.reference ||
    resource?.transaction?.merchant_reference ||
    resource?.transaction?.merchantReference ||
    resource?.transaction?.reference ||
    '',
  ).trim();
}

function extractProviderTransactionId(transaction) {
  const resource = unwrapFedapayResource(transaction);
  return String(
    resource?.id ||
    resource?.transaction_id ||
    resource?.transactionId ||
    resource?.reference ||
    resource?.data?.id ||
    resource?.data?.transaction_id ||
    resource?.data?.transactionId ||
    resource?.data?.reference ||
    resource?.transaction?.id ||
    resource?.transaction?.transaction_id ||
    resource?.transaction?.transactionId ||
    resource?.transaction?.reference ||
    '',
  ).trim();
}

function extractProviderStatus(transaction) {
  const resource = unwrapFedapayResource(transaction);
  return String(
    resource?.status ||
    resource?.state ||
    resource?.data?.status ||
    resource?.data?.state ||
    resource?.transaction?.status ||
    resource?.transaction?.state ||
    '',
  ).trim();
}

function extractProviderAmount(transaction) {
  const resource = unwrapFedapayResource(transaction);
  const value =
    resource?.amount ??
    resource?.gross_amount ??
    resource?.total_amount ??
    resource?.meta?.amount ??
    resource?.data?.amount ??
    resource?.data?.gross_amount ??
    resource?.data?.total_amount ??
    resource?.data?.meta?.amount ??
    resource?.transaction?.amount ??
    resource?.transaction?.gross_amount ??
    resource?.transaction?.total_amount ??
    resource?.transaction?.meta?.amount;
  return normalizeAmount(value);
}

function unwrapFedapayResource(payload) {
  let current = payload;
  const visited = new Set();

  while (
    current &&
    typeof current === 'object' &&
    !Array.isArray(current) &&
    !visited.has(current)
  ) {
    visited.add(current);

    if (
      current.id != null ||
      current.reference != null ||
      current.token != null ||
      current.url != null ||
      current.merchant_reference != null
    ) {
      return current;
    }

    const keys = Object.keys(current);
    if (keys.length === 1) {
      const [onlyKey] = keys;
      const onlyValue = current[onlyKey];
      if (onlyValue && typeof onlyValue === 'object' && !Array.isArray(onlyValue)) {
        return onlyValue;
      }
    }

    for (const key of keys) {
      const value = current[key];
      if (
        value &&
        typeof value === 'object' &&
        !Array.isArray(value) &&
        /transaction|token|payment/i.test(key)
      ) {
        return value;
      }
    }

    const next = current.data || current.transaction || current.payload;
    if (!next || next === current) {
      return current;
    }
    current = next;
  }

  return current;
}

function serializeIntent(intent) {
  if (!intent) {
    return null;
  }

  return {
    id: intent.id,
    userId: intent.userId,
    cycleId: intent.cycleId,
    amount: Number(intent.amount),
    provider: intent.provider,
    merchantReference: intent.merchantReference,
    providerTransactionId: intent.providerTransactionId,
    paymentUrl: intent.paymentUrl,
    callbackUrl: intent.callbackUrl,
    status: intent.status,
    providerStatus: intent.providerStatus,
    failureReason: intent.failureReason,
    depositHistoryId: intent.depositHistoryId,
    approvedAt: intent.approvedAt,
    processedAt: intent.processedAt,
    failedAt: intent.failedAt,
    cancelledAt: intent.cancelledAt,
    expiredAt: intent.expiredAt,
    createdAt: intent.createdAt,
    updatedAt: intent.updatedAt,
  };
}

async function createFedapayTransaction(intent, cycle, requestContext = {}) {
  const callbackUrl = buildReturnUrl(intent.merchantReference);
  const payload = {
    description: `Cotisation tontine ${formatAmount(intent.amount)} F`,
    amount: Math.round(Number(intent.amount)),
    currency: { iso: 'XOF' },
    merchant_reference: intent.merchantReference,
    callback_url: callbackUrl,
    custom_metadata: {
      intentId: intent.id,
      userId: intent.userId,
      cycleId: intent.cycleId,
      source: 'tontine_fedapay',
      initiatedByUserId: requestContext.initiatedByUserId || null,
    },
  };

  const createdTransaction = await requestFedapay('/transactions', {
    method: 'POST',
    body: JSON.stringify(payload),
  });

  const transactionId = extractProviderTransactionId(createdTransaction);
  if (!transactionId) {
    console.warn('[FedaPay] transaction response without id', {
      keys:
        createdTransaction && typeof createdTransaction === 'object'
          ? Object.keys(createdTransaction)
          : [],
    });
    throw new AppError(
      "La transaction FedaPay a ete creee sans identifiant exploitable.",
      502,
      createdTransaction,
    );
  }

  const tokenPayload = await requestFedapay(
    `/transactions/${encodeURIComponent(transactionId)}/token`,
    {
      method: 'POST',
      body: JSON.stringify({}),
    },
  );

  return {
    transactionId,
    providerStatus: extractProviderStatus(createdTransaction) || 'pending',
    paymentUrl:
      tokenPayload?.url ||
      tokenPayload?.payment_url ||
      tokenPayload?.paymentUrl ||
      tokenPayload?.link ||
      tokenPayload?.data?.url ||
      tokenPayload?.data?.payment_url ||
      tokenPayload?.data?.paymentUrl ||
      tokenPayload?.data?.link ||
      null,
    providerPayload: {
      createdTransaction,
      tokenPayload,
      callbackUrl,
    },
  };
}

async function reconcileFedapayIntent(intent, requestContext = {}) {
  if (!intent || intent.status === 'processed') {
    return serializeIntent(intent);
  }

  const providerTransactionId = String(intent.providerTransactionId || '').trim();
  if (!providerTransactionId) {
    return serializeIntent(intent);
  }

  let providerTransaction;
  try {
    providerTransaction = await requestFedapay(
      `/transactions/${encodeURIComponent(providerTransactionId)}`,
      {
        method: 'GET',
      },
    );
  } catch (error) {
    console.warn('[FedaPay] reconciliation skipped', {
      intentId: intent.id,
      providerTransactionId,
      cause: error?.details || error?.message || String(error),
    });
    return serializeIntent(intent);
  }

  const providerStatus = extractProviderStatus(providerTransaction);
  if (providerStatus === 'approved') {
    try {
      return await sequelize.transaction(async (transactionDb) => {
        const lockedIntent = await models.TontinePaymentIntent.findOne({
          where: { id: intent.id },
          transaction: transactionDb,
          lock: transactionDb.LOCK.UPDATE,
          skipLocked: true,
        });

        if (!lockedIntent) {
          return intent;
        }

        if (lockedIntent.status === 'processed') {
          return lockedIntent;
        }

        return syncApprovedFedapayIntent(lockedIntent, providerTransaction, {
          ...requestContext,
          transaction: transactionDb,
        });
      });
    } catch (error) {
      if (isLockWaitTimeoutError(error)) {
        console.warn('[FedaPay] reconciliation lock skipped', {
          intentId: intent.id,
          providerTransactionId,
        });
        return serializeIntent(await intent.reload());
      }
      throw error;
    }
  }

  if (
    providerStatus === 'cancelled' ||
    providerStatus === 'canceled' ||
    providerStatus === 'declined' ||
    providerStatus === 'expired'
  ) {
    const nextStatus =
      providerStatus === 'cancelled' || providerStatus === 'canceled'
        ? 'cancelled'
        : providerStatus === 'declined'
          ? 'failed'
          : 'expired';

    await intent.update({
      providerStatus,
      providerPayload: providerTransaction,
      status: nextStatus,
      ...(nextStatus === 'cancelled' ? { cancelledAt: new Date() } : {}),
      ...(nextStatus === 'failed' ? { failedAt: new Date() } : {}),
      ...(nextStatus === 'expired' ? { expiredAt: new Date() } : {}),
    });

    return serializeIntent(await intent.reload());
  }

  if (providerStatus && providerStatus !== intent.providerStatus) {
    await intent.update({
      providerStatus,
      providerPayload: providerTransaction,
    });
  }

  return serializeIntent(await intent.reload());
}

async function initializeFedapayTontineDeposit(
  userId,
  amount,
  requestContext = {},
) {
  const normalizedAmount = normalizeAmount(amount);
  if (
    !Number.isFinite(normalizedAmount) ||
    normalizedAmount <= 0 ||
    normalizedAmount % FINANCIAL_AMOUNT_STEP !== 0
  ) {
    throw new AppError(
      `Le montant doit etre un multiple positif de ${FINANCIAL_AMOUNT_STEP}.`,
      422,
    );
  }

  const cycleSnapshot = await sequelize.transaction(async (transaction) => {
    const { cycle, remainingAmount } = await getOpenCycleForFunding(
      userId,
      transaction,
    );

    if (normalizedAmount > remainingAmount) {
      throw new AppError(
        `Le montant depasse le reste a verser sur ce cycle. Reste autorise : ${remainingAmount} F.`,
        422,
      );
    }

    const intentId = crypto.randomUUID();
    const merchantReference = buildMerchantReference(intentId);
    const callbackUrl = buildReturnUrl(merchantReference);

    const intent = await models.TontinePaymentIntent.create(
      {
        id: intentId,
        userId,
        cycleId: cycle.id,
        amount: normalizedAmount,
        provider: 'fedapay',
        merchantReference,
        callbackUrl,
        status: 'pending',
        initiatedByUserId: requestContext.initiatedByUserId || null,
        initiatorType: requestContext.initiatorType || 'client',
      },
      { transaction },
    );

    return {
      intent,
      cycle,
      remainingAmount,
      callbackUrl,
    };
  });

  const { intent, cycle, remainingAmount, callbackUrl } = cycleSnapshot;

  try {
    const fedapayTransaction = await createFedapayTransaction(
      intent,
      cycle,
      requestContext,
    );

    try {
      await intent.update({
        providerTransactionId: fedapayTransaction.transactionId,
        paymentUrl: fedapayTransaction.paymentUrl,
        providerStatus: fedapayTransaction.providerStatus,
        providerPayload: fedapayTransaction.providerPayload,
      });
    } catch (updateError) {
      console.warn(
        '[WARN] Impossible de persister le paiement FedaPay initialise:',
        updateError,
      );
    }

    try {
      await writeAuditLog({
        userId,
        action: 'tontine.fedapay_payment_initiated',
        entityType: 'tontinePaymentIntent',
        entityId: intent.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          amount: Number(intent.amount),
          merchantReference: intent.merchantReference,
          providerTransactionId: fedapayTransaction.transactionId,
          paymentUrl: fedapayTransaction.paymentUrl,
          cycleId: cycle.id,
          remainingAmount,
          callbackUrl,
        },
      });
    } catch (auditError) {
      console.warn(
        '[WARN] Audit non enregistre pour le paiement FedaPay:',
        auditError,
      );
    }

    return serializeIntent({
      ...intent.get({ plain: true }),
      providerTransactionId: fedapayTransaction.transactionId,
      paymentUrl: fedapayTransaction.paymentUrl,
      providerStatus: fedapayTransaction.providerStatus,
      providerPayload: fedapayTransaction.providerPayload,
    });
  } catch (error) {
    await intent.update({
      status: 'failed',
      failedAt: new Date(),
      failureReason: error?.message || 'FedaPay initialise a echoue.',
    });
    throw error;
  }
}

async function getFedapayTontineDepositIntent(userId, intentId) {
  const intent = await models.TontinePaymentIntent.findOne({
    where: {
      id: String(intentId || '').trim(),
      userId,
    },
  });

  if (!intent) {
    throw new AppError('Demande de paiement introuvable.', 404);
  }

  return reconcileFedapayIntent(intent, {
    userId,
    initiatorType: 'system',
  });
}

async function syncApprovedFedapayIntent(intent, fedapayTransaction, requestContext) {
  if (intent.status === 'processed') {
    return serializeIntent(intent);
  }

  const amount = Number(intent.amount);
  const providerAmount = extractProviderAmount(fedapayTransaction);
  if (Number.isFinite(providerAmount) && providerAmount !== amount) {
    throw new AppError(
      'Le montant FedaPay ne correspond pas a la demande initiale.',
      422,
      fedapayTransaction,
    );
  }

  const depositResult = await depositToCycle(
    intent.userId,
    amount,
    'fedapay',
    {
      ...requestContext,
      initiatorType: 'system',
      initiatedByUserId: null,
      paymentIntentId: intent.id,
      paymentProvider: 'fedapay',
      transaction: requestContext.transaction,
    },
  );

  await intent.update({
    status: 'processed',
    providerStatus: 'approved',
    providerTransactionId:
      intent.providerTransactionId ||
      extractProviderTransactionId(fedapayTransaction),
    providerPayload: fedapayTransaction,
    approvedAt: intent.approvedAt || new Date(),
    processedAt: new Date(),
    failureReason: null,
    depositHistoryId: depositResult.historyId || null,
  }, {
    transaction: requestContext.transaction,
  });

  await writeAuditLog({
    userId: intent.userId,
    action: 'tontine.fedapay_payment_processed',
    entityType: 'tontinePaymentIntent',
    entityId: intent.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      amount,
      merchantReference: intent.merchantReference,
      providerTransactionId:
        intent.providerTransactionId ||
        extractProviderTransactionId(fedapayTransaction),
      depositHistoryId: depositResult.historyId,
      cycleId: intent.cycleId,
    },
    transaction: requestContext.transaction,
  });

  return serializeIntent(
    await intent.reload({ transaction: requestContext.transaction }),
  );
}

async function processFedapayWebhook(req, res) {
  const signatureHeader =
    req.get('x-fedapay-signature') ||
    req.get('x-fedapay-signaturev2') ||
    req.get('x-fedapay-signature-v2');
  const rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
  const rawBodyText = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody || '');

  if (env.nodeEnv !== 'production') {
    const webhookSecret = String(env.fedapayWebhookSecret || '').trim();
    const replay = webhookSecret
      ? buildWebhookReplayHeader(rawBodyText, webhookSecret)
      : null;
    console.info('[FedaPay webhook debug] replay data', {
      method: req.method,
      path: req.originalUrl || req.url,
      receivedSignature: signatureHeader || null,
      rawBody: rawBodyText,
      replayHeader: replay?.header || null,
    });
  }

  if (!Webhook) {
    throw new AppError(
      'La verification webhook FedaPay n est pas disponible.',
      503,
    );
  }

  let event;
  try {
    event = Webhook.constructEvent(
      rawBody,
      signatureHeader,
      getFedapayWebhookSecret(),
    );

  } catch (error) {
    throw new AppError(
      `Webhook FedaPay invalide: ${error?.message || 'signature refusee'}.`,
      400,
    );
  }

  const eventName = extractFedapayEventName(event);
  const transaction = extractFedapayTransaction(event);
  const merchantReference = extractMerchantReference(transaction);
  const providerTransactionId = extractProviderTransactionId(transaction);
  const providerStatus = extractProviderStatus(transaction);

  if (env.nodeEnv !== 'production') {
    console.info('[FedaPay webhook debug] transaction summary', {
      eventName,
      merchantReference: merchantReference || null,
      providerTransactionId: providerTransactionId || null,
      providerStatus: providerStatus || null,
    });
  }

  if (!merchantReference) {
    return {
      received: true,
      processed: false,
      reason: 'missing_merchant_reference',
      eventName,
    };
  }

  const intent = await models.TontinePaymentIntent.findOne({
    where: { merchantReference },
  });

  if (!intent) {
    return {
      received: true,
      processed: false,
      reason: 'unknown_intent',
      eventName,
      merchantReference,
    };
  }

  if (eventName !== 'transaction.approved') {
    const nextStatus =
      eventName === 'transaction.canceled'
        ? 'cancelled'
        : eventName === 'transaction.declined'
          ? 'failed'
          : eventName === 'transaction.expired'
            ? 'expired'
            : intent.status;
    await intent.update({
      providerTransactionId: intent.providerTransactionId || providerTransactionId,
      providerStatus: providerStatus || intent.providerStatus,
      providerPayload: transaction,
      ...(eventName === 'transaction.canceled'
        ? { status: 'cancelled', cancelledAt: new Date() }
        : {}),
      ...(eventName === 'transaction.declined'
        ? { status: 'failed', failedAt: new Date() }
        : {}),
      ...(eventName === 'transaction.expired'
        ? { status: 'expired', expiredAt: new Date() }
        : {}),
    });

    return {
      received: true,
      processed: false,
      eventName,
      merchantReference,
      intentId: intent.id,
      status: nextStatus,
    };
  }

  if (providerStatus !== 'approved') {
    await intent.update({
      providerTransactionId: intent.providerTransactionId || providerTransactionId,
      providerStatus: providerStatus || intent.providerStatus,
      providerPayload: transaction,
    });
    return {
      received: true,
      processed: false,
      eventName,
      merchantReference,
      intentId: intent.id,
      status: intent.status,
      providerStatus,
    };
  }

  const processedIntent = await sequelize.transaction(async (transactionDb) => {
    const lockedIntent = await models.TontinePaymentIntent.findOne({
      where: { id: intent.id },
      transaction: transactionDb,
      lock: transactionDb.LOCK.UPDATE,
      skipLocked: true,
    });

    if (!lockedIntent) {
      return null;
    }

    if (lockedIntent.status === 'processed') {
      return lockedIntent;
    }

    return syncApprovedFedapayIntent(lockedIntent, transaction, {
      transaction: transactionDb,
      ipAddress: req.ip || null,
      userAgent: req.get('user-agent') || null,
    });
  });

  if (!processedIntent) {
    return {
      received: true,
      processed: false,
      eventName,
      merchantReference,
      intentId: intent.id,
      status: intent.status,
      providerStatus,
      reason: 'locked',
    };
  }

  return {
    received: true,
    processed: true,
    eventName,
    merchantReference,
    intentId: intent.id,
    status: processedIntent.status,
    depositHistoryId: processedIntent.depositHistoryId,
  };
}

async function reconcileFedapayReturnPage(merchantReference, requestContext = {}) {
  const reference = String(merchantReference || '').trim();
  if (!reference) {
    return null;
  }

  const intent = await models.TontinePaymentIntent.findOne({
    where: { merchantReference: reference },
  });

  if (!intent) {
    return null;
  }

  return reconcileFedapayIntent(intent, requestContext);
}

async function renderFedapayReturnPage(req, res) {
  const status = String(req.query.status || '').trim().toLowerCase();
  const merchantReference = String(req.query.merchantReference || '').trim();
  let reconciliationResult = null;

  if (status === 'approved' && merchantReference) {
    try {
      reconciliationResult = await reconcileFedapayReturnPage(merchantReference, {
        initiatorType: 'system',
        ipAddress: req.ip || null,
        userAgent: req.get('user-agent') || null,
      });
    } catch (error) {
      console.warn('[FedaPay] return page reconciliation failed', {
        merchantReference,
        cause: error?.details || error?.message || String(error),
      });
    }
  }

  const title =
    status === 'approved'
      ? 'Paiement accepte'
      : status === 'cancelled'
        ? 'Paiement annule'
        : 'Paiement en attente';
  const message =
    status === 'approved'
      ? reconciliationResult?.status === 'processed'
        ? 'Votre paiement FedaPay a ete recu et la cotisation a ete synchronisee.'
        : 'Votre paiement FedaPay a ete recu. La cotisation sera synchronisee dans quelques instants.'
      : status === 'cancelled'
        ? 'Le paiement a ete annule. Vous pouvez revenir a l application pour recommencer si besoin.'
        : 'Le paiement est en cours de traitement. Vous pouvez revenir a l application et actualiser votre ecran.';

  res
    .status(200)
    .type('html')
    .send(`<!doctype html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      body { font-family: Arial, sans-serif; background: #f5f7fb; color: #11203e; margin: 0; padding: 24px; }
      .card { max-width: 520px; margin: 8vh auto; background: #fff; border-radius: 20px; padding: 28px; box-shadow: 0 10px 30px rgba(16, 24, 40, 0.08); }
      .badge { display: inline-block; padding: 6px 12px; border-radius: 999px; background: #e8eefc; color: #2549b8; font-size: 12px; font-weight: 700; }
      h1 { font-size: 24px; margin: 16px 0 12px; }
      p { line-height: 1.55; color: #4b5563; }
      code { background: #f1f5f9; padding: 2px 6px; border-radius: 8px; }
      .hint { margin-top: 18px; font-size: 13px; color: #6b7280; }
    </style>
  </head>
  <body>
    <main class="card">
      <span class="badge">FedaPay</span>
      <h1>${title}</h1>
      <p>${message}</p>
      ${merchantReference
        ? `<p>Reference: <code>${merchantReference}</code></p>`
        : ''
      }
      <p class="hint">Vous pouvez fermer cette page et revenir a l application.</p>
    </main>
  </body>
</html>`);
}

module.exports = {
  initializeFedapayTontineDeposit,
  getFedapayTontineDepositIntent,
  processFedapayWebhook,
  renderFedapayReturnPage,
};
