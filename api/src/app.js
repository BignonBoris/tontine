const express = require('express');
const cors = require('cors');
const path = require('path');
const env = require('./config/env');
const { mountSwagger } = require('./config/swagger');
const landingRouter = require('./landing/landing.routes');
const apiV1Router = require('./routes/v1');
const notFound = require('./common/middlewares/not-found');
const errorHandler = require('./common/middlewares/error-handler');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
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
app.use(errorHandler);

module.exports = app;
