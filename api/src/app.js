const express = require('express');
const cors = require('cors');
const path = require('path');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const Sentry = require('@sentry/node');
const { nodeProfilingIntegration } = require('@sentry/profiling-node');

const env = require('./config/env');
const { mountSwagger } = require('./config/swagger');
const landingRouter = require('./landing/landing.routes');
const apiV1Router = require('./routes/v1');
const notFound = require('./common/middlewares/not-found');
const errorHandler = require('./common/middlewares/error-handler');

const app = express();

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

app.use(helmet());

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 150,
  message: { message: 'Trop de requêtes, veuillez réessayer plus tard.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', apiLimiter);

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
