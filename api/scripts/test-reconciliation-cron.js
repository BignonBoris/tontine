const { test, mock } = require('node:test');
const assert = require('node:assert/strict');

// Mock models
const mockIntents = [];

const models = {
  TontinePaymentIntent: {
    findAll: mock.fn(async () => mockIntents),
  },
  Wallet: {
    findOne: mock.fn(async () => ({
      totalAvailable: '150000',
      totalReserved: '20000',
      totalTontine: '300000',
    })),
  },
  Goal: {
    findOne: mock.fn(async () => ({
      totalGoalAmount: '50000',
    })),
  },
  CommissionWallet: {
    findOne: mock.fn(async () => ({
      totalCommission: '15000',
      totalPayable: '5000',
    })),
  },
  AgentProfile: {
    findOne: mock.fn(async () => ({
      totalAgentCash: '200000',
    })),
  },
};

const sequelize = {
  transaction: async (cb) => cb({}),
};

// Override require cache
require.cache[require.resolve('../src/database/models')] = {
  exports: { models, sequelize },
};
require.cache[require.resolve('../src/common/services/audit-log.service')] = {
  exports: {
    writeAuditLog: mock.fn(async () => ({})),
  },
};
require.cache[require.resolve('@sentry/node')] = {
  exports: {
    captureMessage: mock.fn(),
    captureException: mock.fn(),
  },
};

require.cache[require.resolve('../src/common/services/reconciliation-cron.service')] = undefined;
const reconciliationCronService = require('../src/common/services/reconciliation-cron.service');

test('CRON Réconciliation: Exécute un cycle et calcule le cantonnement bancaire avec succès', async (t) => {
  const report = await reconciliationCronService.executeReconciliationCycle();

  assert.ok(report);
  assert.equal(report.totalLiabilities, 540000); // 150k + 20k + 300k + 50k + 15k + 5k
  assert.equal(report.assets.agentCash, 200000);
  assert.equal(report.requiredBankReserve, 340000); // 540k - 200k
  assert.equal(report.isHealthy, true);
});
