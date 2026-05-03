const swaggerJsdoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');
const env = require('./env');

const swaggerSpec = swaggerJsdoc({
  definition: {
    openapi: '3.0.3',
    info: {
      title: env.appName,
      version: '1.0.0',
      description: 'Documentation Swagger du MVP maTontine',
    },
    servers: [{ url: `${env.appBaseUrl}/api/v1` }],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        AuthOtpRequest: {
          type: 'object',
          required: ['phoneNumber', 'purpose'],
          properties: {
            phoneNumber: { type: 'string', example: '97000000' },
            purpose: { type: 'string', enum: ['register', 'login'] },
          },
        },
        AuthOtpVerify: {
          type: 'object',
          required: ['phoneNumber', 'code'],
          properties: {
            phoneNumber: { type: 'string', example: '97000000' },
            code: { type: 'string', example: '1234' },
          },
        },
        AgentLoginPayload: {
          type: 'object',
          required: ['phoneNumber', 'pin'],
          properties: {
            phoneNumber: { type: 'string', example: '97000000' },
            pin: { type: 'string', example: '1234' },
          },
        },
        AgentProvisioningPayload: {
          type: 'object',
          required: ['clientUserId', 'amount'],
          properties: {
            clientUserId: { type: 'string', format: 'uuid' },
            amount: { type: 'number', example: 5000 },
            notes: { type: 'string', example: 'Depot terrain agence 01' },
          },
        },
        GoalPayload: {
          type: 'object',
          required: [
            'title',
            'targetAmount',
            'iconCodePoint',
            'colorValue',
            'endDate',
          ],
          properties: {
            title: { type: 'string' },
            targetAmount: { type: 'number' },
            iconCodePoint: { type: 'integer' },
            colorValue: { type: 'integer' },
            endDate: { type: 'string', format: 'date-time' },
            linkedOfferId: { type: 'string' },
            quantity: { type: 'integer', example: 2 },
            unitPrice: { type: 'number', example: 15000 },
          },
        },
        MoneyPayload: {
          type: 'object',
          required: ['amount'],
          properties: {
            amount: { type: 'number', example: 5000 },
          },
        },
        StakePayload: {
          type: 'object',
          required: ['stakeAmount'],
          properties: {
            stakeAmount: { type: 'number', example: 1000 },
          },
        },
        ProfilePayload: {
          type: 'object',
          properties: {
            displayName: { type: 'string' },
            phoneNumber: { type: 'string' },
            accountType: { type: 'string' },
          },
        },
        PreferencesPayload: {
          type: 'object',
          properties: {
            depositNotificationsEnabled: { type: 'boolean' },
            cycleNotificationsEnabled: { type: 'boolean' },
            marketingNotificationsEnabled: { type: 'boolean' },
            pinEnabled: { type: 'boolean' },
            biometricEnabled: { type: 'boolean' },
            pinCode: { type: 'string' },
          },
        },
      },
    },
  },
  apis: ['./src/modules/**/*.routes.js'],
});

function mountSwagger(app) {
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
  app.get('/docs.json', (req, res) => {
    res.json(swaggerSpec);
  });
}

module.exports = { mountSwagger, swaggerSpec };
