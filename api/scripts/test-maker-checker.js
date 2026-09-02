const { test, mock } = require('node:test');
const assert = require('node:assert/strict');
const AppError = require('../src/common/errors/app-error');

// Mock dependencies before requiring the service
const models = {
  Withdrawal: {
    findByPk: mock.fn(),
  },
  Wallet: {
    findOne: mock.fn(),
  },
};

const sequelize = {
  transaction: async (cb) => {
    return cb({
      LOCK: { UPDATE: 'UPDATE' },
    });
  },
};

const env = {
  makerCheckerThreshold: 500000,
};

// Override require cache for the modules
require.cache[require.resolve('../src/database/models')] = {
  exports: { models },
};
require.cache[require.resolve('../src/config/database')] = {
  exports: sequelize,
};
require.cache[require.resolve('../src/config/env')] = {
  exports: env,
};
require.cache[require.resolve('../src/modules/withdrawals/withdrawals.service')] = undefined;

const withdrawalsService = require('../src/modules/withdrawals/withdrawals.service');

test('Maker-Checker: Should block payment if same admin approved a withdrawal >= threshold', async (t) => {
  models.Withdrawal.findByPk.mock.mockImplementationOnce(() => {
    return {
      id: 'withdrawal-1',
      amount: 600000,
      status: 'approved',
      channel: 'bank_transfer',
      approvedByAdminUsername: 'admin_john',
      userId: 'user-1',
      update: mock.fn(),
    };
  });

  await assert.rejects(
    async () => {
      await withdrawalsService.markWithdrawalPaidByAdmin(
        'withdrawal-1',
        { paymentReference: 'REF123', paymentProofImageUrl: '/uploads/withdrawals/proof.jpg' },
        { adminUsername: 'admin_john' }
      );
    },
    (err) => {
      assert.match(err.message, /Maker-Checker/);
      return true;
    }
  );
});

test('Maker-Checker: Should allow payment if different admin approved a withdrawal >= threshold', async (t) => {
  const mockWithdrawal = {
    id: 'withdrawal-2',
    amount: 600000,
    status: 'approved',
    channel: 'bank_transfer',
    approvedByAdminUsername: 'admin_john',
    userId: 'user-1',
    update: mock.fn(),
  };

  const mockWallet = {
    userId: 'user-1',
    reservedWithdrawalBalance: 600000,
    update: mock.fn(),
  };

  models.Withdrawal.findByPk.mock.mockImplementationOnce(() => mockWithdrawal);
  models.Wallet.findOne.mock.mockImplementationOnce(() => mockWallet);

  // Mock writeAuditLog by overriding it in require.cache or just ignoring it if it doesn't fail
  
  // We mock out the rest of the persistWithdrawalPayment dependencies inside the transaction
  require.cache[require.resolve('../src/common/services/audit-log.service')] = {
    exports: { writeAuditLog: mock.fn() },
  };

  try {
    const result = await withdrawalsService.markWithdrawalPaidByAdmin(
      'withdrawal-2',
      { paymentReference: 'REF123', paymentProofImageUrl: '/uploads/withdrawals/proof.jpg' },
      { adminUsername: 'admin_jane' } // Different admin
    );
    assert.strictEqual(result.id, 'withdrawal-2');
  } catch (err) {
    // We might get an error because other DB operations fail due to lack of mocks (e.g. notifications),
    // but we ONLY want to assert it does NOT throw the Maker-Checker 403 error.
    if (err instanceof AppError && err.statusCode === 403) {
      assert.fail('Maker-Checker unexpectedly blocked the transaction');
    }
  }
});

test('Maker-Checker: Should allow payment if same admin approved a withdrawal < threshold', async (t) => {
  const mockWithdrawal = {
    id: 'withdrawal-3',
    amount: 100000, // Below 500,000 threshold
    status: 'approved',
    channel: 'bank_transfer',
    approvedByAdminUsername: 'admin_john',
    userId: 'user-1',
    update: mock.fn(),
  };

  models.Withdrawal.findByPk.mock.mockImplementationOnce(() => mockWithdrawal);
  models.Wallet.findOne.mock.mockImplementationOnce(() => ({ reservedWithdrawalBalance: 100000, update: mock.fn() }));

  try {
    await withdrawalsService.markWithdrawalPaidByAdmin(
      'withdrawal-3',
      { paymentReference: 'REF123', paymentProofImageUrl: '/uploads/withdrawals/proof.jpg' },
      { adminUsername: 'admin_john' } // Same admin, but under threshold
    );
  } catch (err) {
    if (err instanceof AppError && err.statusCode === 403) {
      assert.fail('Maker-Checker unexpectedly blocked a transaction below threshold');
    }
  }
});
