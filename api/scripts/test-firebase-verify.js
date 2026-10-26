const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const AppError = require('../src/common/errors/app-error');

// Mock data
let storedUsers = [];
const mockUser = {
  id: 'user-firebase-001',
  phoneNumber: '0197000001',
  displayName: 'Koffi Mensah',
  firstName: 'Koffi',
  lastName: 'Mensah',
  birthDate: null,
  accountType: 'Personnel',
  isActive: true,
  preferences: {
    pinCode: null,
  },
  update: mock.fn(async () => {}),
};

const models = {
  User: {
    findOne: mock.fn(async ({ where }) => {
      if (where.phoneNumber === '0197000001') {
        return mockUser;
      }
      return null;
    }),
    create: mock.fn(async (data) => {
      const created = {
        ...data,
        id: 'new-user-id',
        isActive: true,
        update: mock.fn(async () => {}),
      };
      storedUsers.push(created);
      return created;
    }),
  },
  UserPreference: {
    findOrCreate: mock.fn(async () => [{ pinCode: null }, true]),
    findOne: mock.fn(async () => ({ pinCode: null })),
  },
  DeviceSession: {
    findOne: mock.fn(async () => null),
    create: mock.fn(async () => ({ id: 'session-001' })),
  },
  DeviceApprovalRequest: {
    findOne: mock.fn(async () => null),
  },
  Wallet: {
    findOrCreate: mock.fn(async () => [{}, true]),
  },
};

const sequelize = {
  transaction: async (cb) => cb({ LOCK: { UPDATE: 'UPDATE' } }),
};

const firebaseAdmin = {
  apps: ['[DEFAULT]'],
  auth: () => ({
    verifyIdToken: mock.fn(async (token) => {
      if (token === 'valid-sim-token') {
        return {
          uid: 'firebase-uid-123',
          phone_number: '+2290197000001',
          firebase: { sign_in_provider: 'phone_pnv' },
        };
      }
      if (token === 'valid-new-user-token') {
        return {
          uid: 'firebase-uid-456',
          phone_number: '+2290196000002',
          firebase: { sign_in_provider: 'phone' },
        };
      }
      throw new Error('Firebase ID token has expired or is invalid.');
    }),
  }),
};

// Override require cache
require.cache[require.resolve('../src/database/models')] = {
  exports: { models, sequelize },
};
require.cache[require.resolve('../src/config/firebase')] = {
  exports: firebaseAdmin,
};
require.cache[require.resolve('../src/common/services/audit-log.service')] = {
  exports: { writeAuditLog: mock.fn(async () => {}) },
};

require.cache[require.resolve('../src/modules/auth/auth.service')] = undefined;
const authService = require('../src/modules/auth/auth.service');

test('Firebase Verify: Rejette si le token est manquant', async (t) => {
  await assert.rejects(
    async () => {
      await authService.verifyFirebaseToken({}, {});
    },
    (err) => {
      assert.equal(err.statusCode, 422);
      assert.match(err.message, /manquant/i);
      return true;
    }
  );
});

test('Firebase Verify: Rejette si le token Firebase est invalide', async (t) => {
  await assert.rejects(
    async () => {
      await authService.verifyFirebaseToken({ idToken: 'invalid-token' }, {});
    },
    (err) => {
      assert.equal(err.statusCode, 401);
      assert.match(err.message, /invalide ou expiré/i);
      return true;
    }
  );
});

test('Firebase Verify: Connexion réussie pour utilisateur certifié SIM existant', async (t) => {
  const result = await authService.verifyFirebaseToken(
    {
      idToken: 'valid-sim-token',
      deviceId: 'device-test-123',
    },
    { ipAddress: '127.0.0.1' }
  );

  assert.ok(result);
  assert.ok(result.token);
  assert.equal(result.user.id, 'user-firebase-001');
  assert.match(result.user.phoneNumber, /97.*00.*00.*01/);
});

test('Firebase Verify: Inscription automatique réussie pour nouveau numéro certifié', async (t) => {
  const result = await authService.verifyFirebaseToken(
    {
      idToken: 'valid-new-user-token',
      firstName: 'Amina',
      lastName: 'Soglo',
      deviceId: 'device-test-456',
      purpose: 'register',
    },
    { ipAddress: '127.0.0.1' }
  );

  assert.ok(result);
  assert.ok(result.token);
  assert.equal(result.user.id, 'new-user-id');
});
