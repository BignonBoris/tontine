async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureColumn(sequelize, columns, columnName, ddl, backfillSql) {
  if (columns[columnName]) {
    return;
  }

  await sequelize.query(`ALTER TABLE wallets ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureWalletCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'wallets');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('wallets');
  await ensureColumn(
    sequelize,
    columns,
    'reserved_withdrawal_balance',
    '`reserved_withdrawal_balance` DECIMAL(18,2) NOT NULL DEFAULT 0',
    'UPDATE wallets SET reserved_withdrawal_balance = 0 WHERE reserved_withdrawal_balance IS NULL',
  );

  await sequelize.query(
    'UPDATE wallets SET reserved_withdrawal_balance = 0 WHERE reserved_withdrawal_balance IS NULL',
  );
}

module.exports = { ensureWalletCompatibility };
