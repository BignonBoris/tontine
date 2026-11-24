/**
 * Fonctions pures du paiement FedaPay "sans redirection" (push USSD).
 * Sans acces base ni reseau : testees dans scripts/test-fedapay-push.js.
 */
const AppError = require('../../common/errors/app-error');

const PUSH_OPERATOR_LABELS = {
  mtn: 'MTN MoMo',
  moov: 'Moov Money',
  celtiis: 'Celtiis Cash',
};

// Codes renvoyes par FedaPay dans `last_error_code`. A completer au fil des cas reels.
const PUSH_ERROR_MESSAGES = {
  INSUFFICIENT_FUND_ERROR:
    'Solde Mobile Money insuffisant. Rechargez votre compte (montant + frais) puis reessayez.',
};

const DEFAULT_PUSH_ERROR_MESSAGE =
  'Le paiement n a pas abouti. Verifiez votre compte Mobile Money puis reessayez.';

function parsePushModes(rawValue) {
  let parsed;
  try {
    parsed = typeof rawValue === 'string' ? JSON.parse(rawValue) : rawValue;
  } catch (_) {
    parsed = null;
  }

  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new AppError(
      'Configuration FEDAPAY_PUSH_MODES invalide (JSON attendu).',
      503,
    );
  }

  const modes = {};
  for (const [operator, mode] of Object.entries(parsed)) {
    const key = String(operator || '').trim().toLowerCase();
    const value = String(mode || '').trim();
    if (key && value) {
      modes[key] = value;
    }
  }
  return modes;
}

/**
 * Normalise un numero beninois au format local a 10 chiffres (01XXXXXXXX).
 * Accepte : espaces/tirets, prefixe +229 / 00229 / 229, ancien format a 8 chiffres
 * (le passage a 10 chiffres consiste a ajouter "01" devant).
 * Retourne null si le numero est invalide.
 */
function normalizeBeninPhone(input) {
  let digits = String(input || '').replace(/\D/g, '');
  if (digits.startsWith('00229')) {
    digits = digits.slice(5);
  } else if (digits.startsWith('229') && digits.length > 10) {
    digits = digits.slice(3);
  }
  if (/^\d{8}$/.test(digits)) {
    digits = `01${digits}`;
  }
  return /^01\d{8}$/.test(digits) ? digits : null;
}

function maskPhone(localPhone) {
  const value = String(localPhone || '');
  if (value.length <= 4) {
    return '••••';
  }
  return `${value.slice(0, 2)}${'•'.repeat(value.length - 4)}${value.slice(-2)}`;
}

/**
 * Valide l'operateur et le numero, et prepare ce qu'il faut envoyer a FedaPay.
 */
function resolvePushTarget({ operator, phoneNumber }, { modes, phoneCountry = 'bj' }) {
  const normalizedOperator = String(operator || '').trim().toLowerCase();
  const mode = modes[normalizedOperator];
  if (!mode) {
    throw new AppError(
      `Operateur Mobile Money non pris en charge. Choix possibles : ${Object.keys(modes).join(', ')}.`,
      422,
    );
  }

  const localPhone = normalizeBeninPhone(phoneNumber);
  if (!localPhone) {
    throw new AppError(
      'Numero Mobile Money invalide. Saisissez un numero a 10 chiffres commencant par 01.',
      422,
    );
  }

  return {
    operator: normalizedOperator,
    operatorLabel: PUSH_OPERATOR_LABELS[normalizedOperator] || normalizedOperator,
    mode,
    localPhone,
    maskedPhone: maskPhone(localPhone),
    fedapayPhone: {
      number: localPhone,
      country: String(phoneCountry || 'bj').toLowerCase(),
    },
  };
}

function describePushError(errorCode) {
  const code = String(errorCode || '').trim().toUpperCase();
  if (!code) {
    return null;
  }
  return PUSH_ERROR_MESSAGES[code] || DEFAULT_PUSH_ERROR_MESSAGE;
}

/**
 * Limite anti-abus : delai minimal entre deux push et nombre maximal par fenetre.
 * `recentCreatedAt` : dates de creation des push recents de l'utilisateur.
 */
function checkPushRateLimit(recentCreatedAt, { now = new Date(), minIntervalSeconds, maxPerWindow, windowMinutes }) {
  const nowMs = now.getTime();
  const windowStart = nowMs - windowMinutes * 60 * 1000;
  const inWindow = recentCreatedAt
    .map((value) => new Date(value).getTime())
    .filter((time) => Number.isFinite(time) && time >= windowStart);

  if (inWindow.length >= maxPerWindow) {
    return {
      allowed: false,
      message: `Trop de demandes de paiement. Reessayez dans quelques minutes.`,
    };
  }

  const latest = inWindow.length ? Math.max(...inWindow) : null;
  if (latest != null) {
    const elapsedSeconds = Math.floor((nowMs - latest) / 1000);
    if (elapsedSeconds < minIntervalSeconds) {
      const waitSeconds = minIntervalSeconds - elapsedSeconds;
      return {
        allowed: false,
        message: `Patientez ${waitSeconds} s avant d envoyer une nouvelle demande de paiement.`,
      };
    }
  }

  return { allowed: true };
}

module.exports = {
  PUSH_OPERATOR_LABELS,
  parsePushModes,
  normalizeBeninPhone,
  maskPhone,
  resolvePushTarget,
  describePushError,
  checkPushRateLimit,
};
