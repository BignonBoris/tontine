/**
 * Test manuel du paiement FedaPay "sans redirection" (push USSD).
 *
 * Crée une transaction, génère son token, déclenche le push vers le numéro
 * indiqué, puis suit le statut jusqu'à un état final. N'écrit rien en base.
 *
 * Usage :
 *   node scripts/fedapay-push-test.js --phone 0197000000 --operator mtn
 *   options : --amount 100   --format local|intl   --timeout 180
 *
 * Clé lue dans api/.env : FEDAPAY_SECRET_KEY (jamais affichée).
 * Avec une clé sk_live_ c'est un VRAI paiement : confirmation demandée.
 */
require('dotenv').config();
const readline = require('readline');

const MODES = { mtn: 'mtn_open', moov: 'moov', celtiis: 'sbin' };

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i].startsWith('--')) {
      args[argv[i].slice(2)] = argv[i + 1];
      i += 1;
    }
  }
  return args;
}

function fail(message) {
  console.error(`\n[ERREUR] ${message}\n`);
  process.exit(1);
}

function maskPhone(phone) {
  return `${phone.slice(0, 2)}${'•'.repeat(Math.max(phone.length - 4, 0))}${phone.slice(-2)}`;
}

function unwrap(payload) {
  if (!payload || typeof payload !== 'object') return payload;
  if (payload.id || payload.token) return payload;
  const nested = Object.values(payload).find(
    (value) => value && typeof value === 'object' && !Array.isArray(value) && (value.id || value.token),
  );
  return nested || payload;
}

function ask(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(question, (answer) => {
    rl.close();
    resolve(answer.trim());
  }));
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const secretKey = String(process.env.FEDAPAY_SECRET_KEY || '').trim();
  if (!secretKey) fail('FEDAPAY_SECRET_KEY absente de api/.env.');

  const isLive = secretKey.startsWith('sk_live_');
  const baseUrl = isLive ? 'https://api.fedapay.com/v1' : 'https://sandbox-api.fedapay.com/v1';

  const operator = String(args.operator || '').toLowerCase();
  const mode = MODES[operator];
  if (!mode) fail(`--operator doit valoir : ${Object.keys(MODES).join(', ')}.`);

  const rawPhone = String(args.phone || '').replace(/\D/g, '');
  const localPhone = rawPhone.startsWith('229') ? rawPhone.slice(3) : rawPhone;
  if (!/^01\d{8}$/.test(localPhone)) {
    fail('--phone doit être un numéro béninois à 10 chiffres commençant par 01 (ex. 0197000000).');
  }
  const format = args.format === 'intl' ? 'intl' : 'local';
  const phoneNumber = {
    number: format === 'intl' ? `+229${localPhone}` : localPhone,
    country: format === 'intl' ? 'BJ' : 'bj',
  };

  const amount = Number(args.amount || 100);
  if (!Number.isInteger(amount) || amount < 100) fail('--amount doit être un entier >= 100.');
  const timeoutSeconds = Number(args.timeout || 180);

  console.log('\n=== Test paiement FedaPay sans redirection ===');
  console.log(`Environnement : ${isLive ? 'LIVE (paiement réel)' : 'SANDBOX'}`);
  console.log(`Opérateur     : ${operator} (mode "${mode}")`);
  console.log(`Numéro        : ${maskPhone(localPhone)} (format ${format})`);
  console.log(`Montant       : ${amount} XOF`);

  if (isLive) {
    const answer = await ask('\nC\'est un VRAI paiement. Tapez OUI pour continuer : ');
    if (answer !== 'OUI') fail('Annulé.');
  }

  async function call(method, path, body) {
    let response;
    try {
      response = await fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${secretKey}`,
        Accept: 'application/json',
        'Content-Type': 'application/json',
      },
      body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(30000),
      });
    } catch (error) {
      const cause = error?.cause;
      fail(
        `Connexion impossible à ${baseUrl}${path} (${method}).\n` +
          `  message : ${error?.message}\n` +
          `  cause   : ${cause?.code || ''} ${cause?.message || ''}`,
      );
    }
    const text = await response.text();
    let payload;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch (error) {
      payload = text;
    }
    return { status: response.status, ok: response.ok, payload };
  }

  function report(step, result) {
    console.log(`\n--- ${step} : HTTP ${result.status}`);
    console.log(JSON.stringify(result.payload, null, 2));
    if (!result.ok) fail(`${step} refusé par FedaPay (HTTP ${result.status}).`);
  }

  // 1. Transaction
  const reference = `PUSHTEST-${Date.now()}`;
  const created = await call('POST', '/transactions', {
    description: `Test push VizioBox ${amount} F`,
    amount,
    currency: { iso: 'XOF' },
    merchant_reference: reference,
    custom_metadata: { source: 'push_test_script' },
    customer: {
      firstname: 'Test',
      lastname: 'VizioBox',
      phone_number: phoneNumber,
    },
  });
  report('1. Création transaction', created);
  const transaction = unwrap(created.payload);
  if (!transaction?.id) fail('Identifiant de transaction introuvable dans la réponse.');

  // 2. Token
  const tokenResult = await call('POST', `/transactions/${transaction.id}/token`, {});
  report('2. Génération du token', tokenResult);
  const token = unwrap(tokenResult.payload)?.token;
  if (!token) fail('Token introuvable dans la réponse.');

  // 3. Push USSD
  const pushResult = await call('POST', `/${mode}`, { token, phone_number: phoneNumber });
  report('3. Envoi du push', pushResult);

  console.log(`\n>>> Validez le paiement sur le téléphone ${maskPhone(localPhone)} (code secret Mobile Money).`);

  // 4. Suivi du statut
  const finalStatuses = ['approved', 'declined', 'canceled', 'cancelled', 'refunded', 'transferred', 'expired'];
  const startedAt = Date.now();
  let lastStatus = null;
  let lastTransaction = null;
  while (Date.now() - startedAt < timeoutSeconds * 1000) {
    await sleep(5000);
    const check = await call('GET', `/transactions/${transaction.id}`);
    lastTransaction = unwrap(check.payload);
    const status = lastTransaction?.status || `HTTP ${check.status}`;
    if (status !== lastStatus) {
      console.log(`[${Math.round((Date.now() - startedAt) / 1000)}s] statut : ${status}`);
      lastStatus = status;
    }
    if (finalStatuses.includes(status)) break;
  }

  if (lastTransaction && typeof lastTransaction === 'object') {
    const details = {};
    for (const key of Object.keys(lastTransaction)) {
      if (/status|error|reason|mode|message|fees|amount|_at$/.test(key)) {
        details[key] = lastTransaction[key];
      }
    }
    console.log('\nDétails finaux FedaPay :');
    console.log(JSON.stringify(details, null, 2));
  }

  console.log(`\n=== Résultat : ${lastStatus} (transaction ${transaction.id}, référence ${reference}) ===\n`);
}

main().catch((error) => fail(error?.message || String(error)));
