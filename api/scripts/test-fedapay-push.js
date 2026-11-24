/**
 * Tests du paiement FedaPay sans redirection (push USSD).
 * Aucun appel reseau ni base : FedaPay (fetch) et les modeles sont simules.
 */
const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');

process.env.FEDAPAY_SECRET_KEY = 'sk_sandbox_test';
process.env.FEDAPAY_API_BASE_URL = 'https://fedapay.test/v1';
process.env.FEDAPAY_PUSH_MODES = '{"mtn":"mtn_open","moov":"moov","celtiis":"sbin"}';

const helpers = require('../src/modules/tontine/fedapay-push.helpers');

// ---------------------------------------------------------------------------
// Fonctions pures
// ---------------------------------------------------------------------------

test('normalizeBeninPhone accepte les formats courants', () => {
  assert.equal(helpers.normalizeBeninPhone('0169965990'), '0169965990');
  assert.equal(helpers.normalizeBeninPhone('01 69 96 59 90'), '0169965990');
  assert.equal(helpers.normalizeBeninPhone('+229 01 69 96 59 90'), '0169965990');
  assert.equal(helpers.normalizeBeninPhone('002290169965990'), '0169965990');
  assert.equal(helpers.normalizeBeninPhone('69965990'), '0169965990');
});

test('normalizeBeninPhone refuse les numeros invalides', () => {
  assert.equal(helpers.normalizeBeninPhone(''), null);
  assert.equal(helpers.normalizeBeninPhone('0269965990'), null);
  assert.equal(helpers.normalizeBeninPhone('016996599'), null);
  assert.equal(helpers.normalizeBeninPhone('+33612345678'), null);
});

test('maskPhone ne montre que les 2 premiers et 2 derniers chiffres', () => {
  assert.equal(helpers.maskPhone('0169965990'), '01••••••90');
});

test('parsePushModes lit la configuration et rejette un JSON invalide', () => {
  assert.deepEqual(helpers.parsePushModes('{"MTN":"mtn_open"," moov ":"moov"}'), {
    mtn: 'mtn_open',
    moov: 'moov',
  });
  assert.throws(() => helpers.parsePushModes('pas du json'), /FEDAPAY_PUSH_MODES/);
  assert.throws(() => helpers.parsePushModes('[]'), /FEDAPAY_PUSH_MODES/);
});

test('resolvePushTarget mappe operateur -> mode FedaPay', () => {
  const modes = helpers.parsePushModes(process.env.FEDAPAY_PUSH_MODES);
  const target = helpers.resolvePushTarget(
    { operator: 'Celtiis', phoneNumber: '01 69 96 59 90' },
    { modes, phoneCountry: 'BJ' },
  );
  assert.equal(target.mode, 'sbin');
  assert.equal(target.operator, 'celtiis');
  assert.equal(target.maskedPhone, '01••••••90');
  assert.deepEqual(target.fedapayPhone, { number: '0169965990', country: 'bj' });

  assert.throws(
    () => helpers.resolvePushTarget({ operator: 'orange', phoneNumber: '0169965990' }, { modes }),
    (error) => error.statusCode === 422,
  );
  assert.throws(
    () => helpers.resolvePushTarget({ operator: 'mtn', phoneNumber: '123' }, { modes }),
    (error) => error.statusCode === 422,
  );
});

test('describePushError traduit les codes FedaPay', () => {
  assert.match(helpers.describePushError('INSUFFICIENT_FUND_ERROR'), /Solde Mobile Money insuffisant/);
  assert.match(helpers.describePushError('CODE_INCONNU'), /n a pas abouti/);
  assert.equal(helpers.describePushError(null), null);
});

test('checkPushRateLimit impose un delai minimal et un plafond', () => {
  const now = new Date('2026-11-24T12:00:00Z');
  const options = { now, minIntervalSeconds: 30, maxPerWindow: 3, windowMinutes: 10 };

  assert.equal(helpers.checkPushRateLimit([], options).allowed, true);

  const tooSoon = helpers.checkPushRateLimit([new Date(now.getTime() - 10_000)], options);
  assert.equal(tooSoon.allowed, false);
  assert.match(tooSoon.message, /Patientez 20 s/);

  assert.equal(
    helpers.checkPushRateLimit([new Date(now.getTime() - 60_000)], options).allowed,
    true,
  );

  const tooMany = helpers.checkPushRateLimit(
    [1, 2, 3].map((minutes) => new Date(now.getTime() - minutes * 60_000)),
    options,
  );
  assert.equal(tooMany.allowed, false);

  // Les demandes hors fenetre ne comptent pas
  const old = helpers.checkPushRateLimit(
    [20, 30, 40].map((minutes) => new Date(now.getTime() - minutes * 60_000)),
    options,
  );
  assert.equal(old.allowed, true);
});

// ---------------------------------------------------------------------------
// Service : modeles, tontine.service, audit et fetch simules
// ---------------------------------------------------------------------------

const src = path.join(__dirname, '..', 'src');
const state = { intents: [], recentPushDates: [], fetchCalls: [], fetchHandler: null, audits: [] };

function makeIntent(fields) {
  const intent = {
    ...fields,
    async update(patch) {
      Object.assign(intent, patch);
      return intent;
    },
    async reload() {
      return intent;
    },
    get() {
      return { ...intent };
    },
  };
  state.intents.push(intent);
  return intent;
}

function stubModule(relativePath, exportsValue) {
  const resolved = require.resolve(path.join(src, relativePath));
  require.cache[resolved] = { id: resolved, filename: resolved, loaded: true, exports: exportsValue };
}

stubModule('database/models/index.js', {
  models: {
    TontinePaymentIntent: {
      create: async (fields) => makeIntent({ createdAt: new Date(), ...fields }),
      findAll: async () => state.recentPushDates.map((createdAt) => ({ createdAt })),
      findOne: async ({ where }) => state.intents.find((item) => item.id === where.id) || null,
    },
    User: {
      findByPk: async () => ({ firstName: 'Awa', lastName: 'Test', displayName: 'Awa' }),
    },
  },
  sequelize: {
    transaction: async (fn) => fn({ LOCK: { UPDATE: 'UPDATE' } }),
  },
});
stubModule('modules/tontine/tontine.service.js', {
  getOpenCycleForFunding: async () => ({ cycle: { id: 'cycle-1' }, remainingAmount: 50000 }),
  depositToCycle: async () => ({ historyId: 'history-1' }),
});
stubModule('common/services/audit-log.service.js', {
  writeAuditLog: async (entry) => state.audits.push(entry),
});

global.fetch = async (url, options = {}) => {
  const body = options.body ? JSON.parse(options.body) : null;
  state.fetchCalls.push({ url, method: options.method, body });
  const { status = 200, payload } = state.fetchHandler(url, options.method, body);
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(payload),
  };
};

function defaultFedapay(url, method) {
  if (url.endsWith('/transactions') && method === 'POST') {
    return { payload: { 'v1/transaction': { id: 114377626, status: 'pending' } } };
  }
  if (url.endsWith('/token')) {
    return { payload: { token: 'TOKEN-123', url: 'https://checkout.fedapay.test/TOKEN-123' } };
  }
  if (url.endsWith('/mtn_open') || url.endsWith('/sbin') || url.endsWith('/moov')) {
    return { payload: { message: 'ok' } };
  }
  if (url.includes('/transactions/') && method === 'GET') {
    return {
      payload: {
        'v1/transaction': {
          id: 114377626,
          status: 'canceled',
          last_error_code: 'INSUFFICIENT_FUND_ERROR',
          amount: 100,
        },
      },
    };
  }
  return { status: 404, payload: { message: 'not found' } };
}

const service = require('../src/modules/tontine/tontine-fedapay.service');

beforeEach(() => {
  state.intents.length = 0;
  state.recentPushDates = [];
  state.fetchCalls.length = 0;
  state.audits.length = 0;
  state.fetchHandler = defaultFedapay;
});

test('push : cree la transaction, envoie le push au bon mode et masque le numero', async () => {
  const result = await service.initializeFedapayTontinePushDeposit(
    'user-1',
    100,
    { operator: 'mtn', phoneNumber: '+229 01 69 96 59 90' },
    { ipAddress: '127.0.0.1' },
  );

  const [createCall, tokenCall, pushCall] = state.fetchCalls;
  assert.equal(createCall.url, 'https://fedapay.test/v1/transactions');
  assert.deepEqual(createCall.body.customer.phone_number, { number: '0169965990', country: 'bj' });
  assert.equal(createCall.body.amount, 100);
  assert.match(tokenCall.url, /\/transactions\/114377626\/token$/);
  assert.equal(pushCall.url, 'https://fedapay.test/v1/mtn_open');
  assert.deepEqual(pushCall.body, {
    token: 'TOKEN-123',
    phone_number: { number: '0169965990', country: 'bj' },
  });

  assert.equal(result.channel, 'push');
  assert.equal(result.status, 'pending');
  assert.equal(result.pushOperator, 'mtn');
  assert.equal(result.pushPhoneMasked, '01••••••90');
  assert.ok(result.pushSentAt);
  assert.equal(result.paymentUrl, 'https://checkout.fedapay.test/TOKEN-123');

  const audit = state.audits.find((entry) => entry.action === 'tontine.fedapay_push_sent');
  assert.equal(audit.metadata.phone, '01••••••90');
  assert.ok(!JSON.stringify(state.audits).includes('0169965990'), 'numero complet absent de l audit');
});

test('push : operateur inconnu refuse avant tout appel FedaPay', async () => {
  await assert.rejects(
    service.initializeFedapayTontinePushDeposit('user-1', 100, {
      operator: 'orange',
      phoneNumber: '0169965990',
    }),
    (error) => error.statusCode === 422,
  );
  assert.equal(state.fetchCalls.length, 0);
  assert.equal(state.intents.length, 0);
});

test('push : limite de frequence (429) sans creer de demande', async () => {
  state.recentPushDates = [new Date(Date.now() - 5_000)];
  await assert.rejects(
    service.initializeFedapayTontinePushDeposit('user-1', 100, {
      operator: 'mtn',
      phoneNumber: '0169965990',
    }),
    (error) => error.statusCode === 429,
  );
  assert.equal(state.intents.length, 0);
  assert.equal(state.fetchCalls.length, 0);
});

test('push : refus FedaPay -> demande en echec avec code et message clair', async () => {
  state.fetchHandler = (url, method, body) => {
    if (url.endsWith('/mtn_open')) {
      return { status: 400, payload: { message: 'refused', last_error_code: 'INSUFFICIENT_FUND_ERROR' } };
    }
    return defaultFedapay(url, method, body);
  };

  await assert.rejects(
    service.initializeFedapayTontinePushDeposit('user-1', 100, {
      operator: 'mtn',
      phoneNumber: '0169965990',
    }),
    (error) => /Solde Mobile Money insuffisant/.test(error.message),
  );

  const [intent] = state.intents;
  assert.equal(intent.status, 'failed');
  assert.equal(intent.lastErrorCode, 'INSUFFICIENT_FUND_ERROR');
  assert.ok(intent.failedAt);
});

test('suivi : annulation operateur remontee avec un message lisible', async () => {
  const pushed = await service.initializeFedapayTontinePushDeposit('user-1', 100, {
    operator: 'mtn',
    phoneNumber: '0169965990',
  });

  const tracked = await service.reconcileFedapayIntent(
    state.intents.find((item) => item.id === pushed.id),
  );
  assert.equal(tracked.status, 'cancelled');
  assert.equal(tracked.lastErrorCode, 'INSUFFICIENT_FUND_ERROR');
  assert.match(tracked.failureMessage, /Solde Mobile Money insuffisant/);
});
