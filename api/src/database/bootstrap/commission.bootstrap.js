const { DataTypes } = require('sequelize');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureColumn(queryInterface, tableName, columns, columnName, spec) {
  if (columns[columnName]) {
    return;
  }
  await queryInterface.addColumn(tableName, columnName, spec);
}

async function ensureCommissionRulesTable(queryInterface) {
  if (await tableExists(queryInterface, 'commission_rules')) {
    return;
  }

  await queryInterface.createTable('commission_rules', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    code: { type: DataTypes.STRING(64), allowNull: false, unique: true },
    name: { type: DataTypes.STRING(160), allowNull: false },
    status: { type: DataTypes.STRING(16), allowNull: false, defaultValue: 'active' },
    calculation_mode: {
      type: DataTypes.STRING(16),
      allowNull: false,
      defaultValue: 'fixed',
    },
    fixed_cycle_commission_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    platform_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    deposit_agent_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    withdrawal_agent_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    bonus_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    floating_enabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    created_by_admin_id: { type: DataTypes.STRING(64), allowNull: true },
    updated_by_admin_id: { type: DataTypes.STRING(64), allowNull: true },
    effective_from: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    effective_to: { type: DataTypes.DATE, allowNull: true },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureCycleCommissionSnapshotsTable(queryInterface) {
  if (await tableExists(queryInterface, 'cycle_commission_snapshots')) {
    return;
  }

  await queryInterface.createTable('cycle_commission_snapshots', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    tontine_cycle_id: { type: DataTypes.UUID, allowNull: false, unique: true },
    commission_rule_id: { type: DataTypes.UUID, allowNull: false },
    user_id: { type: DataTypes.UUID, allowNull: false },
    stake_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    cycle_commission_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    platform_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    deposit_agent_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    withdrawal_agent_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    bonus_share_rate: {
      type: DataTypes.DECIMAL(8, 4),
      allowNull: false,
      defaultValue: 0,
    },
    floating_enabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    snapshot_payload: { type: DataTypes.JSON, allowNull: false },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureCommissionWalletsTable(queryInterface) {
  if (await tableExists(queryInterface, 'commission_wallets')) {
    return;
  }

  await queryInterface.createTable('commission_wallets', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    owner_type: { type: DataTypes.STRING(16), allowNull: false },
    owner_id: { type: DataTypes.STRING(64), allowNull: false },
    wallet_type: { type: DataTypes.STRING(32), allowNull: false },
    balance: { type: DataTypes.DECIMAL(18, 2), allowNull: false, defaultValue: 0 },
    payable_balance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    blocked_balance: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    currency: { type: DataTypes.STRING(8), allowNull: false, defaultValue: 'XOF' },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureCommissionLedgerEntriesTable(queryInterface) {
  if (await tableExists(queryInterface, 'commission_ledger_entries')) {
    return;
  }

  await queryInterface.createTable('commission_ledger_entries', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    reference: { type: DataTypes.STRING(80), allowNull: false, unique: true },
    entry_type: { type: DataTypes.STRING(64), allowNull: false },
    status: { type: DataTypes.STRING(16), allowNull: false, defaultValue: 'posted' },
    source_type: { type: DataTypes.STRING(64), allowNull: false },
    source_id: { type: DataTypes.STRING(64), allowNull: true },
    cycle_id: { type: DataTypes.UUID, allowNull: true },
    client_id: { type: DataTypes.UUID, allowNull: true },
    agent_id: { type: DataTypes.UUID, allowNull: true },
    wallet_id: { type: DataTypes.UUID, allowNull: true },
    direction: { type: DataTypes.STRING(16), allowNull: false },
    amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    payable_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    blocked_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    currency: { type: DataTypes.STRING(8), allowNull: false, defaultValue: 'XOF' },
    commission_bucket: { type: DataTypes.STRING(32), allowNull: false },
    snapshot_id: { type: DataTypes.UUID, allowNull: true },
    trigger_event: { type: DataTypes.STRING(64), allowNull: true },
    initiated_by_user_id: { type: DataTypes.UUID, allowNull: true },
    initiator_type: { type: DataTypes.STRING(32), allowNull: true },
    reversal_of_entry_id: { type: DataTypes.UUID, allowNull: true },
    metadata: { type: DataTypes.JSON, allowNull: false },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureWithdrawalCommissionReservesTable(queryInterface) {
  if (await tableExists(queryInterface, 'withdrawal_commission_reserves')) {
    return;
  }

  await queryInterface.createTable('withdrawal_commission_reserves', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    client_id: { type: DataTypes.UUID, allowNull: false },
    cycle_id: { type: DataTypes.UUID, allowNull: false, unique: true },
    snapshot_id: { type: DataTypes.UUID, allowNull: false },
    stake_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    source_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    remaining_source_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    consumed_source_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    initial_reserved_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    available_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    consumed_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    sequence: { type: DataTypes.INTEGER, allowNull: false },
    status: { type: DataTypes.STRING(16), allowNull: false, defaultValue: 'open' },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureWithdrawalCommissionConsumptionsTable(queryInterface) {
  if (await tableExists(queryInterface, 'withdrawal_commission_consumptions')) {
    return;
  }

  await queryInterface.createTable('withdrawal_commission_consumptions', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    reference: { type: DataTypes.STRING(80), allowNull: false, unique: true },
    withdrawal_id: { type: DataTypes.STRING(64), allowNull: false },
    client_id: { type: DataTypes.UUID, allowNull: false },
    reserve_id: { type: DataTypes.UUID, allowNull: false },
    cycle_id: { type: DataTypes.UUID, allowNull: false },
    agent_id: { type: DataTypes.UUID, allowNull: true },
    consumed_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    agent_commission_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    platform_commission_amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 0,
    },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureCommissionSeed(sequelize, models) {
  const existingRule = await models.CommissionRule.findOne({
    where: { code: 'tontine-default-v1' },
  });
  if (existingRule) {
    return;
  }

  await models.CommissionRule.create({
    code: 'tontine-default-v1',
    name: 'Commission tontine par defaut',
    status: 'active',
    calculationMode: 'fixed',
    fixedCycleCommissionAmount: 0,
    platformShareRate: 0.30,
    depositAgentShareRate: 0.30,
    withdrawalAgentShareRate: 0.30,
    bonusShareRate: 0.10,
    floatingEnabled: true,
  });
}

async function ensureWalletCompatibility(queryInterface) {
  if (!(await tableExists(queryInterface, 'wallets'))) {
    return;
  }
  const columns = await queryInterface.describeTable('wallets');
  await ensureColumn(queryInterface, 'wallets', columns, 'reserved_withdrawal_balance', {
    type: DataTypes.DECIMAL(18, 2),
    allowNull: false,
    defaultValue: 0,
  });
}

async function ensureProvisioningsCompatibility(queryInterface) {
  if (!(await tableExists(queryInterface, 'provisionings'))) {
    return;
  }

  const columns = await queryInterface.describeTable('provisionings');
  await ensureColumn(queryInterface, 'provisionings', columns, 'cycle_id', {
    type: DataTypes.UUID,
    allowNull: true,
  });
  await ensureColumn(queryInterface, 'provisionings', columns, 'reversed_at', {
    type: DataTypes.DATE,
    allowNull: true,
  });
  await ensureColumn(queryInterface, 'provisionings', columns, 'reversed_by_user_id', {
    type: DataTypes.UUID,
    allowNull: true,
  });
  await ensureColumn(queryInterface, 'provisionings', columns, 'reversal_reason', {
    type: DataTypes.STRING(255),
    allowNull: true,
  });
}

async function ensureWithdrawalsTable(queryInterface) {
  if (await tableExists(queryInterface, 'withdrawals')) {
    return;
  }

  await queryInterface.createTable('withdrawals', {
    id: { type: DataTypes.UUID, primaryKey: true, allowNull: false },
    reference: { type: DataTypes.STRING(64), allowNull: false, unique: true },
    user_id: { type: DataTypes.UUID, allowNull: false },
    amount: { type: DataTypes.DECIMAL(18, 2), allowNull: false },
    status: { type: DataTypes.STRING(16), allowNull: false, defaultValue: 'requested' },
    channel: { type: DataTypes.STRING(32), allowNull: false, defaultValue: 'cash' },
    requested_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    paid_at: { type: DataTypes.DATE, allowNull: true },
    cancelled_at: { type: DataTypes.DATE, allowNull: true },
    rejected_at: { type: DataTypes.DATE, allowNull: true },
    paid_by_agent_profile_id: { type: DataTypes.UUID, allowNull: true },
    initiated_by_user_id: { type: DataTypes.UUID, allowNull: true },
    initiator_type: { type: DataTypes.STRING(32), allowNull: true },
    notes: { type: DataTypes.STRING(255), allowNull: true },
    created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
  });
}

async function ensureCommissionCompatibility(sequelize, models) {
  const queryInterface = sequelize.getQueryInterface();
  await ensureWalletCompatibility(queryInterface);
  await ensureProvisioningsCompatibility(queryInterface);
  await ensureWithdrawalsTable(queryInterface);
  await ensureCommissionRulesTable(queryInterface);
  await ensureCycleCommissionSnapshotsTable(queryInterface);
  await ensureCommissionWalletsTable(queryInterface);
  await ensureCommissionLedgerEntriesTable(queryInterface);
  await ensureWithdrawalCommissionReservesTable(queryInterface);
  await ensureWithdrawalCommissionConsumptionsTable(queryInterface);
  await ensureCommissionSeed(sequelize, models);
}

module.exports = { ensureCommissionCompatibility };
