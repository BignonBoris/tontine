const Sentry = require('@sentry/node');
const { nodeProfilingIntegration } = require('@sentry/profiling-node');
const env = require('./config/env');

if (env.sentryDsn) {
  Sentry.init({
    dsn: env.sentryDsn,
    integrations: [
      nodeProfilingIntegration(),
    ],
    tracesSampleRate: 1.0,
    profilesSampleRate: 1.0,
  });
}

const express = require('express');
const cors = require('cors');
const path = require('path');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

const { mountSwagger } = require('./config/swagger');
const landingRouter = require('./landing/landing.routes');
const apiV1Router = require('./routes/v1');
const notFound = require('./common/middlewares/not-found');
const errorHandler = require('./common/middlewares/error-handler');

const app = express();

// Permet à express-rate-limit de lire correctement l'IP derrière un reverse-proxy (comme Render)
app.set('trust proxy', 1);

app.use(helmet());

// ─── Rate Limiters ──────────────────────────────────────────────────────────

// Limiteur global : 150 req / 15 min par IP
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 150,
  message: { message: 'Trop de requêtes, veuillez réessayer plus tard.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', apiLimiter);

// Limiteur strict : demande d'OTP / vérification PIN client
// 5 requêtes / 15 min → rend le brute-force d'un PIN 4 chiffres (10 000 combos)
// impossible dans une fenêtre raisonnable.
const otpRequestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { message: 'Trop de tentatives. Veuillez réessayer dans 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: false,
});

// Limiteur modéré : vérification OTP (le code est à usage unique, mais on bloque quand même)
const otpVerifyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { message: 'Trop de tentatives de vérification. Veuillez réessayer plus tard.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Limiteur strict : login agent (PIN 4 chiffres)
const agentLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 8,
  message: { message: 'Trop de tentatives de connexion agent. Veuillez réessayer dans 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // ne compte pas les connexions réussies
});

// Application des limiteurs spécifiques AVANT le routeur global
app.use('/api/v1/auth/request-otp', otpRequestLimiter);
app.use('/api/v1/auth/resend-otp', otpRequestLimiter);
app.use('/api/v1/auth/verify-otp', otpVerifyLimiter);
app.use('/api/v1/agent/auth/login', agentLoginLimiter);

// ────────────────────────────────────────────────────────────────────────────

app.use(cors());
app.use(
  express.json({
    limit: '10mb',
    verify: (req, res, buffer) => {
      req.rawBody = buffer;
    },
  }),
);
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(express.static(path.join(__dirname, 'public')));

app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: `${env.appName} running`,
  });
});

if (env.swaggerEnabled) {
  mountSwagger(app);
}

app.use('/', landingRouter);
app.use('/api/v1', apiV1Router);

app.use(notFound);
if (env.sentryDsn) {
  Sentry.setupExpressErrorHandler(app);
}
app.use(errorHandler);

module.exports = app;
