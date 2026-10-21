const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const AppError = require('../src/common/errors/app-error');

// Mock dependencies
const mockCreatedProvisioning = {
  id: 'prov-12345',
  reference: 'PRV-1234567890-0001',
  cycleId: 'cycle-001',
  amount: 5000,
  status: 'validated',
  source: 'agent',
  notes: 'Cotisation test',
  syncId: 'uuid-offline-sync-001',
  validatedAt: new Date(),
  client: {
    id: 'client-user-1',
    displayName: 'Amina Diallo',
    phoneNumber: '+22997000000',
  },
};

const mockAgentProfile = {
  id: 'agent-profile-1',
  userId: 'agent-user-1',
  fullName: 'Agent Terrain 1',
  agentBalance: 50000,
};

let storedProvisionings = [];

const models = {
  Provisioning: {
    findOne: mock.fn(async ({ where }) => {
      if (where.syncId) {
        return storedProvisionings.find((p) => p.syncId === where.syncId) || null;
      }
      return null;
    }),
    create: mock.fn(async (data) => {
      const record = { ...data, id: 'prov-new-id' };
      storedProvisionings.push(record);
      return record;
    }),
  },
  AgentProfile: {
    findByPk: mock.fn(async () => mockAgentProfile),
  },
  User: {
    findByPk: mock.fn(async () => ({
      id: 'client-user-1',
      isActive: true,
      displayName: 'Amina Diallo',
      phoneNumber: '+22997000000',
    })),
  },
  TontineHistory: {
    findOne: mock.fn(async () => null),
  },
  Notification: {
    create: mock.fn(async () => ({})),
  },
};

const sequelize = {
  transaction: async (cb) => {
    return cb({
      LOCK: { UPDATE: 'UPDATE' },
    });
  },
};

// Override require cache
require.cache[require.resolve('../src/database/models')] = {
  exports: { models, sequelize },
};
require.cache[require.resolve('../src/config/database')] = {
  exports: sequelize,
};
require.cache[require.resolve('../src/modules/tontine/tontine.service')] = {
  exports: {
    depositToCycle: mock.fn(async () => ({})),
    getOpenCycleForFunding: mock.fn(async () => ({
      remainingAmount: 31000,
      cycle: { id: 'cycle-001' },
    })),
    hasActiveOrAwaitingCycle: mock.fn(async () => true),
    reverseProvisioningDepositOnCycle: mock.fn(async () => ({})),
  },
};
require.cache[require.resolve('../src/modules/agent-cash/agent-cash.service')] = {
  exports: {
    applyAgentBalanceChange: mock.fn(async () => ({
      balanceBefore: 50000,
      balanceAfter: 45000,
    })),
  },
};
require.cache[require.resolve('../src/common/services/audit-log.service')] = {
  exports: {
    writeAuditLog: mock.fn(async () => ({})),
  },
};

require.cache[require.resolve('../src/modules/agent-provisionings/agent-provisionings.service')] = undefined;
const agentProvisioningsService = require('../src/modules/agent-provisionings/agent-provisionings.service');

test('R-04 Offline Idempotence: First request creates a new provisioning', async (t) => {
  storedProvisionings = [];

  const payload = {
    clientUserId: 'client-user-1',
    amount: 5000,
    notes: 'Cotisation marché',
    syncId: 'uuid-offline-sync-001',
  };

  const result = await agentProvisioningsService.createProvisioning(mockAgentProfile, payload);

  assert.ok(result);
  assert.equal(result.amount, 5000);
  assert.equal(result.client.id, 'client-user-1');
  assert.equal(storedProvisionings.length, 1);
});

test('R-04 Offline Idempotence: Duplicate request with same syncId returns existing without double debit', async (t) => {
  // Simulate the existing record in database
  storedProvisionings = [mockCreatedProvisioning];

  const payload = {
    clientUserId: 'client-user-1',
    amount: 5000,
    notes: 'Cotisation marché (rejeu réseau)',
    syncId: 'uuid-offline-sync-001',
  };

  const initialLength = storedProvisionings.length;
  const result = await agentProvisioningsService.createProvisioning(mockAgentProfile, payload);

  // Must return the existing record directly
  assert.ok(result);
  assert.equal(result.id, 'prov-12345');
  assert.equal(result.reference, 'PRV-1234567890-0001');
  assert.equal(result.amount, 5000);

  // Must NOT have inserted any new record
  assert.equal(storedProvisionings.length, initialLength);
});
