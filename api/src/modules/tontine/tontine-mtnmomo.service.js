const crypto = require('crypto');
const AppError = require('../../common/errors/app-error');
const env = require('../../config/env');
const { writeAuditLog } = require('../../common/services/audit-log.service');
const { models, sequelize } = require('../../database/models');
const { getOpenCycleForFunding, depositToCycle } = require('./tontine.service');
const { FINANCIAL_AMOUNT_STEP } = require('../../common/constants/finance');

const MTN_REQUEST_TO_PAY_PATH = '/collection/v1_0/requesttopay';
const MTN_TOKEN_PATH = '/collection/token/';
const MTN_REQUEST_TIMEOUT_MESSAGE =
  'MTN MoMo a refuse la requete.';

let cachedAccessToken = null;
let cachedAccessTokenExpiresAt = 0;
let tokenPromise = null;

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

function normalizeLower(value) {
  return String(value || '').trim().toLowerCase();
}

function getMtnMomoBaseUrl() {
  return String(env.mtnMomoApiBaseUrl || '').replace(/\/+$/, '');
}

function getMtnMomoTargetEnvironment() {
  const targetEnvironment = normalizeLower(env.mtnMomoTargetEnvironment || 'sandbox');
  if (!targetEnvironment) {
    throw new AppError('MTN MoMo n est pas configure sur le serveur.', 503);
  }
  return targetEnvironment;
}

function getMtnMomoSubscriptionKey() {
  const subscriptionKey = String(env.mtnMomoCollectionSubscriptionKey || '').trim();
  if (!subscriptionKey) {
    throw new AppError('La cle de souscription MTN MoMo n est pas configuree.', 503);
  }
  return subscriptionKey;
}

function getMtnMomoApiUser() {
  const apiUser = String(env.mtnMomoApiUser || '').trim();
  if (!apiUser) {
    throw new AppError('L utilisateur API MTN MoMo n est pas configure.', 503);
  }
  return apiUser;
}

function getMtnMomoApiKey() {
  const apiKey = String(env.mtnMomoApiKey || '').trim();
  if (!apiKey) {
    throw new AppError('La cle API MTN MoMo n est pas configuree.', 503);
  }
  return apiKey;
}

function getMtnMomoCurrency() {
  const currency = String(env.mtnMomoCurrency || '').trim().toUpperCase();
  if (!currency) {
    throw new AppError('La devise MTN MoMo n est pas configuree.', 503);
  }
  return currency;
}

function getMtnMomoCallbackBaseUrl() {
  const baseUrl = String(
    env.mtnMomoCallbackBaseUrl || env.appBaseUrl || '',
  ).replace(/\/+$/, '');
  if (!baseUrl) {
    throw new AppError('L URL de callback MTN MoMo n est pas configuree.', 503);
  }
  return baseUrl;
}

function getMtnMomoCountryCode() {
  return String(env.mtnMomoMsisdnCountryCode || '').replace(/\D/g, '');
}

function buildCallbackUrl() {
  return `${getMtnMomoCallbackBaseUrl()}/api/v1/tontine/mtn-momo/webhook`;
}

function buildMerchantReference(intentId) {
  return `MTN-${String(intentId || '').replace(/-/g, '').slice(0, 32)}`;
}

function normalizeMsisdn(phoneNumber) {
  const digits = String(phoneNumber || '').replace(/\D/g, '');
  if (!digits) {
    return '';
  }

  if (digits.length > 10) {
    return digits;
  }

  const countryCode = getMtnMomoCountryCode();
  if (!countryCode) {
    return '';
  }

  return `${countryCode}${digits.replace(/^0+/, '')}`;
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

function unwrapMtnResource(payload) {
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
      current.referenceId != null ||
      current.externalId != null ||
      current.financialTransactionId != null ||
      current.status != null ||
      current.amount != null ||
      current.id != null
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
        /request|payment|transaction|callback|resource/i.test(key)
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

function extractMtnReferenceId(payload) {
  const resource = unwrapMtnResource(payload);
  return String(
    resource?.referenceId ||
    resource?.reference_id ||
    resource?.id ||
    resource?.transactionId ||
    resource?.transaction_id ||
    resource?.financialTransactionId ||
    resource?.financial_transaction_id ||
    resource?.data?.referenceId ||
    resource?.data?.reference_id ||
    resource?.data?.id ||
    resource?.data?.transactionId ||
    resource?.data?.transaction_id ||
    resource?.data?.financialTransactionId ||
    resource?.data?.financial_transaction_id ||
    '',
  ).trim();
}

function extractMtnExternalId(payload) {
  const resource = unwrapMtnResource(payload);
  return String(
    resource?.externalId ||
    resource?.external_id ||
    resource?.merchantReference ||
    resource?.merchant_reference ||
    resource?.data?.externalId ||
    resource?.data?.external_id ||
    resource?.data?.merchantReference ||
    resource?.data?.merchant_reference ||
    '',
  ).trim();
}

function extractMtnStatus(payload) {
  const resource = unwrapMtnResource(payload);
  return normalizeLower(
    resource?.status ||
    resource?.state ||
    resource?.result ||
    resource?.data?.status ||
    resource?.data?.state ||
    resource?.data?.result ||
    '',
  );
}

function extractMtnAmount(payload) {
  const resource = unwrapMtnResource(payload);
  const value =
    resource?.amount ??
    resource?.data?.amount ??
    resource?.payment?.amount ??
    resource?.transaction?.amount ??
    resource?.payer?.amount;
  return normalizeAmount(value);
}

function extractMtnCurrency(payload) {
  const resource = unwrapMtnResource(payload);
  return String(
    resource?.currency ||
      resource?.data?.currency ||
      resource?.payment?.currency ||
      resource?.transaction?.currency ||
      '',
  ).trim().toUpperCase();
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

function isLockWaitTimeoutError(error) {
  const message = String(error?.message || '');
  return (
    message.includes('Lock wait timeout exceeded') ||
    message.includes('ER_LOCK_WAIT_TIMEOUT') ||
    error?.original?.errno === 1205 ||
    error?.parent?.errno === 1205
  );
}

async function requestMtnMomo(path, options = {}) {
  const url = `${getMtnMomoBaseUrl()}${path}`;
  const isTokenRequest = path === MTN_TOKEN_PATH;

  try {
    const headers = {
      Accept: 'application/json',
      ...(options.headers || {}),
    };

    if (!isTokenRequest) {
      headers.Authorization = `Bearer ${await getMtnMomoAccessToken()}`;
      headers['Ocp-Apim-Subscription-Key'] = getMtnMomoSubscriptionKey();
      headers['X-Target-Environment'] = getMtnMomoTargetEnvironment();
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    const payload = await parseJsonResponse(response);
    if (!response.ok) {
      throw new AppError(
        extractMessage(payload, MTN_REQUEST_TIMEOUT_MESSAGE),
        502,
        payload,
      );
    }

    return payload;
  } catch (error) {
    const cause =
      error?.cause?.code ||
      error?.cause?.message ||
      error?.message ||
      String(error);

    console.warn('[MTN MoMo] request failed', {
      url,
      cause,
    });

    if (error instanceof AppError) {
      throw error;
    }

    throw new AppError(
      `Impossible de joindre MTN MoMo (${url}). Verifiez MTN_MOMO_API_BASE_URL, la connectivite sortante du serveur et le DNS.`,
      503,
      { cause, url },
    );
  }
}

async function getMtnMomoAccessToken() {
  const now = Date.now();
  if (cachedAccessToken && cachedAccessTokenExpiresAt > now) {
    return cachedAccessToken;
  }

  if (tokenPromise) {
    return tokenPromise;
  }

  tokenPromise = (async () => {
    const apiUser = getMtnMomoApiUser();
    const apiKey = getMtnMomoApiKey();
    const credentials = Buffer.from(`${apiUser}:${apiKey}`).toString('base64');

    const response = await fetch(`${getMtnMomoBaseUrl()}${MTN_TOKEN_PATH}`, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        Authorization: `Basic ${credentials}`,
        'Ocp-Apim-Subscription-Key': getMtnMomoSubscriptionKey(),
        'X-Target-Environment': getMtnMomoTargetEnvironment(),
      },
    });

    const payload = await parseJsonResponse(response);
    if (!response.ok) {
      throw new AppError(
        extractMessage(payload, 'Impossible de generer le token MTN MoMo.'),
        502,
        payload,
      );
    }

    const accessToken = String(
      payload?.access_token ||
      payload?.accessToken ||
      payload?.token ||
      '',
    ).trim();

    if (!accessToken) {
      throw new AppError(
        'Le token MTN MoMo n a pas pu etre extrait de la reponse.',
        502,
        payload,
      );
    }

    const expiresIn = Number(payload?.expires_in || payload?.expiresIn || 3600);
    const ttlMs = Number.isFinite(expiresIn) && expiresIn > 60
      ? (expiresIn - 30) * 1000
      : 30 * 60 * 1000;

    cachedAccessToken = accessToken;
    cachedAccessTokenExpiresAt = now + ttlMs;

    return accessToken;
  })();

  try {
    return await tokenPromise;
  } finally {
    tokenPromise = null;
  }
}

function mapProviderStatusToIntentStatus(providerStatus) {
  const status = normalizeLower(providerStatus);

  if (!status) {
    return null;
  }

  if (status === 'successful' || status === 'success' || status === 'approved') {
    return 'approved';
  }

  if (status === 'pending' || status === 'ongoing' || status === 'delivered') {
    return 'processing';
  }

  if (
    status === 'rejected' ||
    status === 'cancelled' ||
    status === 'canceled'
  ) {
    return 'cancelled';
  }

  if (status === 'expired' || status === 'timed_out' || status === 'timeout') {
    return 'expired';
  }

  if (
    status === 'failed' ||
    status === 'declined' ||
    status === 'invalid' ||
    status === 'notfound'
  ) {
    return 'failed';
  }

  return null;
}

async function syncApprovedMtnMomoIntent(intent, providerTransaction, requestContext) {
  if (intent.status === 'processed') {
    return serializeIntent(intent);
  }

  const amount = Number(intent.amount);
  const providerAmount = extractMtnAmount(providerTransaction);
  if (Number.isFinite(providerAmount) && providerAmount !== amount) {
    throw new AppError(
      'Le montant MTN MoMo ne correspond pas a la demande initiale.',
      422,
      providerTransaction,
    );
  }

  const providerCurrency = extractMtnCurrency(providerTransaction);
  const expectedCurrency = getMtnMomoCurrency();
  if (providerCurrency && providerCurrency !== expectedCurrency) {
    throw new AppError(
      'La devise MTN MoMo ne correspond pas a la configuration attendue.',
      422,
      providerTransaction,
    );
  }

  const depositResult = await depositToCycle(
    intent.userId,
    amount,
    'mtn_momo',
    {
      ...requestContext,
      initiatorType: 'system',
      initiatedByUserId: null,
      paymentIntentId: intent.id,
      paymentProvider: 'mtn_momo',
      transaction: requestContext.transaction,
    },
  );

  await intent.update(
    {
      status: 'processed',
      approvedAt: intent.approvedAt || new Date(),
      processedAt: new Date(),
      providerStatus: normalizeLower(extractMtnStatus(providerTransaction) || intent.providerStatus || 'successful'),
      providerPayload: providerTransaction,
      depositHistoryId: depositResult.historyId || intent.depositHistoryId || null,
      failureReason: null,
    },
    { transaction: requestContext.transaction },
  );

  await writeAuditLog({
    userId: intent.userId,
    action: 'tontine.mtn_momo_payment_processed',
    entityType: 'tontinePaymentIntent',
    entityId: intent.id,
    ipAddress: requestContext.ipAddress,
    userAgent: requestContext.userAgent,
    metadata: {
      amount,
      merchantReference: intent.merchantReference,
      providerTransactionId: intent.providerTransactionId,
      providerStatus: extractMtnStatus(providerTransaction),
      depositHistoryId: depositResult.historyId || null,
    },
    transaction: requestContext.transaction,
  });

  return serializeIntent(await intent.reload({ transaction: requestContext.transaction }));
}

async function reconcileMtnMomoIntent(intent, requestContext = {}) {
  if (!intent || intent.status === 'processed') {
    return serializeIntent(intent);
  }

  const providerTransactionId = String(intent.providerTransactionId || '').trim();
  if (!providerTransactionId) {
    return serializeIntent(intent);
  }

  let providerTransaction = null;
  try {
    providerTransaction = await requestMtnMomo(
      `${MTN_REQUEST_TO_PAY_PATH}/${encodeURIComponent(providerTransactionId)}`,
      { method: 'GET' },
    );
  } catch (error) {
    console.warn('[MTN MoMo] reconciliation skipped', {
      intentId: intent.id,
      providerTransactionId,
      cause: error?.details || error?.message || String(error),
    });
    return serializeIntent(intent);
  }

  const providerStatus = extractMtnStatus(providerTransaction);
  const mappedStatus = mapProviderStatusToIntentStatus(providerStatus);

  if (mappedStatus === 'approved') {
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

        return syncApprovedMtnMomoIntent(lockedIntent, providerTransaction, {
          ...requestContext,
          transaction: transactionDb,
        });
      });
    } catch (error) {
      if (isLockWaitTimeoutError(error)) {
        console.warn('[MTN MoMo] reconciliation lock skipped', {
          intentId: intent.id,
          providerTransactionId,
        });
        return serializeIntent(await intent.reload());
      }
      throw error;
    }
  }

  if (mappedStatus) {
    const patch = {
      providerStatus,
      providerPayload: providerTransaction,
    };

    if (mappedStatus === 'cancelled') {
      patch.status = 'cancelled';
      patch.cancelledAt = new Date();
    } else if (mappedStatus === 'expired') {
      patch.status = 'expired';
      patch.expiredAt = new Date();
    } else if (mappedStatus === 'failed') {
      patch.status = 'failed';
      patch.failedAt = new Date();
    } else if (mappedStatus === 'processing') {
      patch.status = intent.status === 'pending' ? 'processing' : intent.status;
    }

    if (mappedStatus !== 'approved') {
      await intent.update(patch);
      return serializeIntent(await intent.reload());
    }
  }

  if (providerStatus && providerStatus !== normalizeLower(intent.providerStatus)) {
    await intent.update({
      providerStatus,
      providerPayload: providerTransaction,
    });
  }

  return serializeIntent(await intent.reload());
}

async function initializeMtnMomoTontineDeposit(
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

  const client = await models.User.findByPk(userId, {
    attributes: ['id', 'phoneNumber', 'displayName', 'isActive'],
  });

  if (!client) {
    throw new AppError('Utilisateur introuvable.', 404);
  }

  const payerPhoneNumber = normalizeMsisdn(client.phoneNumber);
  if (!payerPhoneNumber) {
    throw new AppError(
      'Le client doit disposer d un numero de telephone avec indicatif pays pour MTN MoMo.',
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
    const callbackUrl = buildCallbackUrl();

    const intent = await models.TontinePaymentIntent.create(
      {
        id: intentId,
        userId,
        cycleId: cycle.id,
        amount: normalizedAmount,
        provider: 'mtn_momo',
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
    const requestReferenceId = crypto.randomUUID();
    const requestPayload = {
      amount: Math.round(Number(intent.amount)),
      currency: getMtnMomoCurrency(),
      externalId: intent.merchantReference,
      payer: {
        partyIdType: 'MSISDN',
        partyId: payerPhoneNumber,
      },
      payerMessage: `Cotisation tontine ${formatAmount(intent.amount)} F`,
      payeeNote: 'Versement tontine',
    };

    const requestResponse = await requestMtnMomo(MTN_REQUEST_TO_PAY_PATH, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Reference-Id': requestReferenceId,
        'X-Callback-Url': callbackUrl,
      },
      body: JSON.stringify(requestPayload),
    });

    try {
      await intent.update({
        providerTransactionId: requestReferenceId,
        providerStatus: 'pending',
        providerPayload: {
          requestPayload,
          requestResponse,
          callbackUrl,
          requestReferenceId,
        },
      });
    } catch (updateError) {
      console.warn(
        '[WARN] Impossible de persister le paiement MTN MoMo initialise:',
        updateError,
      );
    }

    try {
      await writeAuditLog({
        userId,
        action: 'tontine.mtn_momo_payment_initiated',
        entityType: 'tontinePaymentIntent',
        entityId: intent.id,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        metadata: {
          amount: Number(intent.amount),
          merchantReference: intent.merchantReference,
          providerTransactionId: requestReferenceId,
          callbackUrl,
          cycleId: cycle.id,
          remainingAmount,
          payerPhoneNumber,
        },
      });
    } catch (auditError) {
      console.warn(
        '[WARN] Audit non enregistre pour le paiement MTN MoMo:',
        auditError,
      );
    }

    return serializeIntent({
      ...intent.get({ plain: true }),
      providerTransactionId: requestReferenceId,
      providerStatus: 'pending',
      providerPayload: {
        requestPayload,
        requestResponse,
        callbackUrl,
        requestReferenceId,
      },
    });
  } catch (error) {
    await intent.update({
      status: 'failed',
      failedAt: new Date(),
      failureReason: error?.message || 'MTN MoMo initialise a echoue.',
    });
    throw error;
  }
}

async function getMtnMomoTontineDepositIntent(userId, intentId) {
  const intent = await models.TontinePaymentIntent.findOne({
    where: {
      id: String(intentId || '').trim(),
      userId,
    },
  });

  if (!intent) {
    throw new AppError('Demande de paiement introuvable.', 404);
  }

  return reconcileMtnMomoIntent(intent, {
    userId,
    initiatorType: 'system',
  });
}

async function processMtnMomoWebhook(req) {
  const payload = req.body || {};
  const referenceId = extractMtnReferenceId(payload);
  const externalId = extractMtnExternalId(payload);
  const providerStatus = extractMtnStatus(payload);

  let intent = null;
  if (referenceId) {
    intent = await models.TontinePaymentIntent.findOne({
      where: {
        providerTransactionId: referenceId,
      },
    });
  }

  if (!intent && externalId) {
    intent = await models.TontinePaymentIntent.findOne({
      where: {
        merchantReference: externalId,
      },
    });
  }

  if (!intent) {
    console.warn('[MTN MoMo] webhook ignored: no intent found', {
      referenceId: referenceId || null,
      externalId: externalId || null,
      status: providerStatus || null,
    });
    return {
      received: true,
      matched: false,
      status: 'ignored',
    };
  }

  return sequelize.transaction(async (transactionDb) => {
    const lockedIntent = await models.TontinePaymentIntent.findOne({
      where: { id: intent.id },
      transaction: transactionDb,
      lock: transactionDb.LOCK.UPDATE,
      skipLocked: true,
    });

    if (!lockedIntent) {
      return {
        received: true,
        matched: true,
        locked: true,
      };
    }

    if (
      referenceId &&
      !String(lockedIntent.providerTransactionId || '').trim()
    ) {
      await lockedIntent.update(
        { providerTransactionId: referenceId },
        { transaction: transactionDb },
      );
    }

    if (providerStatus === 'successful' || providerStatus === 'success' || providerStatus === 'approved') {
      return syncApprovedMtnMomoIntent(lockedIntent, payload, {
        userId: lockedIntent.userId,
        initiatorType: 'system',
        transaction: transactionDb,
        ipAddress: req.ip || null,
        userAgent: req.get('user-agent') || null,
      });
    }

    const mappedStatus = mapProviderStatusToIntentStatus(providerStatus);
    if (mappedStatus === 'cancelled' || mappedStatus === 'failed' || mappedStatus === 'expired') {
      const patch = {
        providerStatus,
        providerPayload: payload,
        status: mappedStatus,
        ...(mappedStatus === 'cancelled' ? { cancelledAt: new Date() } : {}),
        ...(mappedStatus === 'failed' ? { failedAt: new Date() } : {}),
        ...(mappedStatus === 'expired' ? { expiredAt: new Date() } : {}),
      };

      await lockedIntent.update(patch, { transaction: transactionDb });
      return serializeIntent(await lockedIntent.reload({ transaction: transactionDb }));
    }

    await lockedIntent.update(
      {
        providerStatus: providerStatus || lockedIntent.providerStatus,
        providerPayload: payload,
      },
      { transaction: transactionDb },
    );

    return serializeIntent(await lockedIntent.reload({ transaction: transactionDb }));
  });
}

module.exports = {
  initializeMtnMomoTontineDeposit,
  getMtnMomoTontineDepositIntent,
  processMtnMomoWebhook,
  // exported for tests / future reuse
  normalizeMsisdn,
  serializeIntent,
};
