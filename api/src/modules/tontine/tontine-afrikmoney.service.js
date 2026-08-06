const crypto = require('crypto');
const AppError = require('../../common/errors/app-error');
const env = require('../../config/env');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { getOpenCycleForFunding, depositToCycle } = require('./tontine.service');
const { FINANCIAL_AMOUNT_STEP } = require('../../common/constants/finance');

const AFRIKMONEY_REQUEST_PATH = '/api/v1/request';
const AFRIKMONEY_VERIFY_PATH_PREFIX = '/api/v1/';

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

function getAfrikmoneyBaseUrl() {
  return String(env.afrikmoneyApiBaseUrl || 'https://pay.afrikmoney.com').replace(/\/+$/, '');
}

function getAfrikmoneyApiKey() {
  const apiKey = String(env.afrikmoneyApiKey || '').trim();
  if (!apiKey) {
    throw new AppError('Afrikmoney n est pas configure sur le serveur.', 503);
  }
  return apiKey;
}

function getAfrikmoneyWebhookSecret() {
  const secret = String(env.afrikmoneyWebhookSecret || '').trim();
  if (!secret) {
    throw new AppError('Le secret de webhook Afrikmoney n est pas configure.', 503);
  }
  return secret;
}

function buildMerchantReference(intentId) {
  return `AFK-${String(intentId || '').replace(/-/g, '').slice(0, 32)}`;
}

function extractCustomerPhone(phoneNumber) {
  const digits = String(phoneNumber || '').replace(/\D/g, '');
  if (!digits) {
    return '';
  }

  if (digits.length < 8 || digits.length > 13) {
    throw new AppError(
      'Le numero de telephone du client est invalide pour Afrikmoney.',
      422,
    );
  }

  return digits;
}

function extractCustomerEmail(user, phoneDigits) {
  const existingEmail = String(
    user?.email || user?.emailAddress || user?.contactEmail || '',
  )
    .trim()
    .toLowerCase();

  if (existingEmail) {
    return existingEmail;
  }

  const fallbackDigits = String(phoneDigits || '').replace(/\D/g, '');
  const emailDomain = String(env.afrikmoneyCustomerEmailDomain || 'example.com')
    .trim()
    .replace(/^@+/, '');

  if (!fallbackDigits || !emailDomain) {
    return '';
  }

  return `client.${fallbackDigits}@${emailDomain}`;
}

function extractCustomerName(user) {
  const firstName = String(user?.firstName || '').trim();
  const lastName = String(user?.lastName || '').trim();
  const displayName = String(user?.displayName || '').trim();
  const fromIdentity = `${firstName} ${lastName}`.trim();
  return fromIdentity || displayName || 'Client maTontine';
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

function unwrapAfrikmoneyResource(payload) {
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
      current.merchant_reference != null ||
      current.payment_url != null ||
      current.checkout_url != null ||
      current.status != null ||
      current.transaction_id != null
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
        /transaction|payment|checkout|request|payload|result/i.test(key)
      ) {
        return value;
      }
    }

    const next = current.data || current.transaction || current.payload || current.result;
    if (!next || next === current) {
      return current;
    }
    current = next;
  }

  return current;
}

function extractAfrikmoneyEventName(payload) {
  const resource = unwrapAfrikmoneyResource(payload);
  return String(
    resource?.event ||
      resource?.name ||
      resource?.type ||
      resource?.data?.event ||
      resource?.data?.name ||
      resource?.data?.type ||
      '',
  ).trim();
}

function extractAfrikmoneyTransaction(payload) {
  const candidates = [
    payload?.transaction,
    payload?.data?.transaction,
    payload?.data,
    payload?.payload?.transaction,
    payload?.payload?.data,
    payload,
  ];

  for (const candidate of candidates) {
    if (candidate && typeof candidate === 'object') {
      return unwrapAfrikmoneyResource(candidate);
    }
  }

  return null;
}

function extractMerchantReference(transaction) {
  const resource = unwrapAfrikmoneyResource(transaction);
  return String(
    resource?.merchant_reference ||
      resource?.merchantReference ||
      resource?.data?.merchant_reference ||
      resource?.data?.merchantReference ||
      resource?.transaction?.merchant_reference ||
      resource?.transaction?.merchantReference ||
      '',
  ).trim();
}

function extractProviderTransactionId(transaction) {
  const resource = unwrapAfrikmoneyResource(transaction);
  return String(
    resource?.reference ||
      resource?.transaction_id ||
      resource?.transactionId ||
      resource?.id ||
      resource?.checkout_reference ||
      resource?.data?.reference ||
      resource?.data?.transaction_id ||
      resource?.data?.transactionId ||
      resource?.data?.id ||
      resource?.data?.checkout_reference ||
      resource?.transaction?.reference ||
      resource?.transaction?.transaction_id ||
      resource?.transaction?.transactionId ||
      resource?.transaction?.id ||
      resource?.transaction?.checkout_reference ||
      '',
  ).trim();
}

function extractProviderStatus(transaction) {
  const resource = unwrapAfrikmoneyResource(transaction);
  return String(
    resource?.status ||
      resource?.state ||
      resource?.result ||
      resource?.data?.status ||
      resource?.data?.state ||
      resource?.data?.result ||
      '',
  )
    .trim()
    .toLowerCase();
}

function extractProviderAmount(transaction) {
  const resource = unwrapAfrikmoneyResource(transaction);
  const value =
    resource?.net_amount ??
    resource?.amount ??
    resource?.total ??
    resource?.total_amount ??
    resource?.data?.net_amount ??
    resource?.data?.amount ??
    resource?.data?.total ??
    resource?.data?.total_amount ??
    resource?.transaction?.net_amount ??
    resource?.transaction?.amount ??
    resource?.transaction?.total ??
    resource?.transaction?.total_amount;
  return normalizeAmount(value);
}

function extractPaymentUrl(payload) {
  const resource = unwrapAfrikmoneyResource(payload);
  return String(
    resource?.payment_url ||
      resource?.checkout_url ||
      resource?.url ||
      resource?.data?.payment_url ||
      resource?.data?.checkout_url ||
      resource?.data?.url ||
      '',
  ).trim();
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

async function requestAfrikmoney(path, options = {}) {
  const url = `${getAfrikmoneyBaseUrl()}${path}`;

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        Authorization: `Bearer ${getAfrikmoneyApiKey()}`,
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      },
    });

    const payload = await parseJsonResponse(response);
    if (!response.ok) {
      throw new AppError(
        extractMessage(payload, 'Afrikmoney a refuse la requete.'),
        502,
        payload,
      );
    }

    return unwrapAfrikmoneyResource(payload);
  } catch (error) {
    const cause =
      error?.cause?.code ||
      error?.cause?.message ||
      error?.message ||
      String(error);

    console.warn('[Afrikmoney] request failed', {
      url,
      cause,
    });

    if (error instanceof AppError) {
      throw error;
    }

    throw new AppError(
      `Impossible de joindre Afrikmoney (${url}). Verifiez AFRIKMONEY_API_BASE_URL, la connectivite sortante du serveur et le DNS.`,
      503,
      { cause, url },
    );
  }
}

function buildWebhookReplaySignature(rawBody, secret = getAfrikmoneyWebhookSecret()) {
  const payload = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody || '');
  const signature = crypto
    .createHmac('sha256', secret)
    .update(payload, 'utf8')
    .digest('hex');

  return {
    signature,
    header: signature,
    payload,
  };
}

function normalizeWebhookSignatureHeader(headerValue) {
  return String(headerValue || '')
    .trim()
    .replace(/^sha256=/i, '')
    .replace(/^hmac-sha256=/i, '');
}

function assertAfrikmoneyWebhookSignature(rawBody, signatureHeader) {
  const payload = Buffer.isBuffer(rawBody) ? rawBody.toString('utf8') : String(rawBody || '');
  const expectedSignature = crypto
    .createHmac('sha256', getAfrikmoneyWebhookSecret())
    .update(payload, 'utf8')
    .digest('hex');
  const receivedSignature = normalizeWebhookSignatureHeader(signatureHeader);

  if (!receivedSignature || receivedSignature.length !== expectedSignature.length) {
    return false;
  }

  try {
    return crypto.timingSafeEqual(
      Buffer.from(receivedSignature, 'hex'),
      Buffer.from(expectedSignature, 'hex'),
    );
  } catch (_) {
    return receivedSignature.toLowerCase() === expectedSignature.toLowerCase();
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

async function createAfrikmoneyPaymentLink(intent, user, requestContext = {}) {
  const customerPhone = extractCustomerPhone(user?.phoneNumber);
  if (!customerPhone) {
    throw new AppError(
      "Le client n a pas de numero de telephone exploitable pour Afrikmoney.",
      422,
    );
  }
  const customerEmail = extractCustomerEmail(user, customerPhone);
  if (!customerEmail) {
    throw new AppError(
      "Le client n a pas d adresse email exploitable pour Afrikmoney.",
      422,
    );
  }

  const payload = {
    amount: Math.round(Number(intent.amount)),
    customer_phone: customerPhone,
    customer_email: customerEmail,
    customer_name: extractCustomerName(user),
    description: `Cotisation tontine ${formatAmount(intent.amount)} F`,
  };

  const createdPayment = await requestAfrikmoney(AFRIKMONEY_REQUEST_PATH, {
    method: 'POST',
    body: JSON.stringify({
      ...payload,
    }),
  });

  const providerTransactionId = extractProviderTransactionId(createdPayment);
  const paymentUrl = extractPaymentUrl(createdPayment);
  const providerStatus = extractProviderStatus(createdPayment) || 'pending';

  if (!providerTransactionId && !paymentUrl) {
    throw new AppError(
      "La reponse Afrikmoney ne contient pas d identifiant de paiement exploitable.",
      502,
      createdPayment,
    );
  }

  return {
    providerTransactionId: providerTransactionId || null,
    paymentUrl: paymentUrl || null,
    providerStatus,
    providerPayload: {
      requestPayload: payload,
      createdPayment,
    },
  };
}

async function syncApprovedAfrikmoneyIntent(
  intent,
  providerTransaction,
  requestContext = {},
) {
  if (intent.status === 'processed') {
    return serializeIntent(intent);
  }

  const amount = Number(intent.amount);
  const providerAmount = extractProviderAmount(providerTransaction);
  if (Number.isFinite(providerAmount) && providerAmount !== amount) {
    throw new AppError(
      'Le montant Afrikmoney ne correspond pas a la demande initiale.',
      422,
      providerTransaction,
    );
  }

  const depositResult = await depositToCycle(
    intent.userId,
    amount,
    'afrikmoney',
    {
      ...requestContext,
      initiatorType: 'system',
      initiatedByUserId: null,
      paymentIntentId: intent.id,
      paymentProvider: 'afrikmoney',
      transaction: requestContext.transaction,
    },
  );

  await intent.update(
    {
      status: 'processed',
      providerStatus: 'success',
      providerTransactionId:
        intent.providerTransactionId ||
        extractProviderTransactionId(providerTransaction),
      providerPayload: providerTransaction,
      approvedAt: intent.approvedAt || new Date(),
      processedAt: new Date(),
      failureReason: null,
      depositHistoryId: depositResult.historyId || null,
    },
    {
      transaction: requestContext.transaction,
    },
  );

  await writeAuditLog({
    userId: intent.userId,
    action: 'tontine.afrikmoney_payment_processed',
    entityType: 'tontinePaymentIntent',
    entityId: intent.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      amount,
      merchantReference: intent.merchantReference,
      providerTransactionId:
        intent.providerTransactionId ||
        extractProviderTransactionId(providerTransaction),
      depositHistoryId: depositResult.historyId,
      cycleId: intent.cycleId,
    },
    transaction: requestContext.transaction,
  });

  return serializeIntent(
    await intent.reload({ transaction: requestContext.transaction }),
  );
}

async function reconcileAfrikmoneyIntent(intent, requestContext = {}) {
  if (!intent || intent.status === 'processed') {
    return serializeIntent(intent);
  }

  const reference =
    String(intent.merchantReference || '').trim() ||
    String(intent.providerTransactionId || '').trim();
  if (!reference) {
    return serializeIntent(intent);
  }

  let providerTransaction;
  try {
    providerTransaction = await requestAfrikmoney(
      `${AFRIKMONEY_VERIFY_PATH_PREFIX}${encodeURIComponent(reference)}/verify`,
      {
        method: 'GET',
      },
    );
  } catch (error) {
    console.warn('[Afrikmoney] reconciliation skipped', {
      intentId: intent.id,
      reference,
      cause: error?.details || error?.message || String(error),
    });
    return serializeIntent(intent);
  }

  const providerStatus = extractProviderStatus(providerTransaction);
  if (
    providerStatus === 'success' ||
    providerStatus === 'succeeded' ||
    providerStatus === 'completed' ||
    providerStatus === 'approved'
  ) {
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

        return syncApprovedAfrikmoneyIntent(lockedIntent, providerTransaction, {
          ...requestContext,
          transaction: transactionDb,
        });
      });
    } catch (error) {
      if (isLockWaitTimeoutError(error)) {
        console.warn('[Afrikmoney] reconciliation lock skipped', {
          intentId: intent.id,
          reference,
        });
        return serializeIntent(await intent.reload());
      }
      throw error;
    }
  }

  if (
    providerStatus === 'failed' ||
    providerStatus === 'cancelled' ||
    providerStatus === 'canceled' ||
    providerStatus === 'expired'
  ) {
    const nextStatus =
      providerStatus === 'failed'
        ? 'failed'
        : providerStatus === 'expired'
          ? 'expired'
          : 'cancelled';

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

async function initializeAfrikmoneyTontineDeposit(
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

  const user = await models.User.findByPk(userId);
  if (!user) {
    throw new AppError('Client introuvable.', 404);
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

    const intent = await models.TontinePaymentIntent.create(
      {
        id: intentId,
        userId,
        cycleId: cycle.id,
        amount: normalizedAmount,
        provider: 'afrikmoney',
        merchantReference,
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
    };
  });

  const { intent, cycle, remainingAmount } = cycleSnapshot;

  try {
    const paymentLink = await createAfrikmoneyPaymentLink(
      intent,
      user,
      requestContext,
    );

    try {
      await intent.update({
        providerTransactionId: paymentLink.providerTransactionId,
        paymentUrl: paymentLink.paymentUrl,
        providerStatus: paymentLink.providerStatus,
        providerPayload: paymentLink.providerPayload,
      });
    } catch (updateError) {
      console.warn(
        '[WARN] Impossible de persister le paiement Afrikmoney initialise:',
        updateError,
      );
    }

    try {
      await writeAuditLog({
        userId,
        action: 'tontine.afrikmoney_payment_initiated',
        entityType: 'tontinePaymentIntent',
        entityId: intent.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          amount: Number(intent.amount),
          merchantReference: intent.merchantReference,
          providerTransactionId: paymentLink.providerTransactionId,
          paymentUrl: paymentLink.paymentUrl,
          cycleId: cycle.id,
          remainingAmount,
        },
      });
    } catch (auditError) {
      console.warn(
        '[WARN] Audit non enregistre pour le paiement Afrikmoney:',
        auditError,
      );
    }

    return serializeIntent({
      ...intent.get({ plain: true }),
      providerTransactionId: paymentLink.providerTransactionId,
      paymentUrl: paymentLink.paymentUrl,
      providerStatus: paymentLink.providerStatus,
      providerPayload: paymentLink.providerPayload,
    });
  } catch (error) {
    await intent.update({
      status: 'failed',
      failedAt: new Date(),
      failureReason: error?.message || 'Afrikmoney initialise a echoue.',
    });
    throw error;
  }
}

async function getAfrikmoneyTontineDepositIntent(userId, intentId) {
  const intent = await models.TontinePaymentIntent.findOne({
    where: {
      id: String(intentId || '').trim(),
      userId,
    },
  });

  if (!intent) {
    throw new AppError('Demande de paiement introuvable.', 404);
  }

  return reconcileAfrikmoneyIntent(intent, {
    userId,
    initiatorType: 'system',
  });
}

async function processAfrikmoneyWebhook(req) {
  const signatureHeader =
    req.get('x-webhook-signature') || req.get('x-afrikmoney-signature');
  const rawBody = req.rawBody || Buffer.from(JSON.stringify(req.body || {}));
  const rawBodyText = Buffer.isBuffer(rawBody)
    ? rawBody.toString('utf8')
    : String(rawBody || '');

  if (env.nodeEnv !== 'production') {
    const replay = buildWebhookReplaySignature(rawBodyText);
    console.info('[Afrikmoney webhook debug] replay data', {
      method: req.method,
      path: req.originalUrl || req.url,
      receivedSignature: signatureHeader || null,
      rawBody: rawBodyText,
      replayHeader: replay.header,
    });
  }

  if (!assertAfrikmoneyWebhookSignature(rawBodyText, signatureHeader)) {
    throw new AppError(
      'Webhook Afrikmoney invalide: signature refusee.',
      400,
    );
  }

  const payload = req.body || {};
  const eventName = extractAfrikmoneyEventName(payload);
  const transaction = extractAfrikmoneyTransaction(payload);
  const merchantReference = extractMerchantReference(transaction);
  const providerTransactionId = extractProviderTransactionId(transaction);
  const providerStatus = extractProviderStatus(transaction);

  if (env.nodeEnv !== 'production') {
    console.info('[Afrikmoney webhook debug] transaction summary', {
      eventName,
      merchantReference: merchantReference || null,
      providerTransactionId: providerTransactionId || null,
      providerStatus: providerStatus || null,
    });
  }

  if (!merchantReference && !providerTransactionId) {
    return {
      received: true,
      processed: false,
      reason: 'missing_reference',
      eventName,
    };
  }

  let intent = null;
  if (merchantReference) {
    intent = await models.TontinePaymentIntent.findOne({
      where: { merchantReference },
    });
  }

  if (!intent && providerTransactionId) {
    intent = await models.TontinePaymentIntent.findOne({
      where: {
        providerTransactionId,
      },
    });
  }

  if (!intent) {
    return {
      received: true,
      processed: false,
      reason: 'unknown_intent',
      eventName,
      merchantReference,
      providerTransactionId,
    };
  }

  if (
    eventName !== 'transaction.success' &&
    providerStatus !== 'success' &&
    providerStatus !== 'succeeded' &&
    providerStatus !== 'completed' &&
    providerStatus !== 'approved'
  ) {
    const nextStatus =
      providerStatus === 'failed'
        ? 'failed'
        : providerStatus === 'expired'
          ? 'expired'
          : providerStatus === 'cancelled' || providerStatus === 'canceled'
            ? 'cancelled'
            : intent.status;

    await intent.update({
      providerTransactionId: intent.providerTransactionId || providerTransactionId,
      providerStatus: providerStatus || intent.providerStatus,
      providerPayload: transaction,
      ...(nextStatus === 'failed' ? { status: 'failed', failedAt: new Date() } : {}),
      ...(nextStatus === 'expired' ? { status: 'expired', expiredAt: new Date() } : {}),
      ...(nextStatus === 'cancelled'
        ? { status: 'cancelled', cancelledAt: new Date() }
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

    return syncApprovedAfrikmoneyIntent(lockedIntent, transaction, {
      userId: lockedIntent.userId,
      initiatorType: 'system',
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

module.exports = {
  initializeAfrikmoneyTontineDeposit,
  getAfrikmoneyTontineDepositIntent,
  processAfrikmoneyWebhook,
};
