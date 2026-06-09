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

  await sequelize.query(`ALTER TABLE goals ADD ${ddl};`);
  if (backfillSql) {
    await sequelize.query(backfillSql);
  }
}

async function ensureGoalCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'goals');
  if (!exists) {
    return;
  }

  const columns = await queryInterface.describeTable('goals');

  await ensureColumn(
    sequelize,
    columns,
    'linked_offer_id',
    '`linked_offer_id` VARCHAR(64) NULL',
  );
  await ensureColumn(
    sequelize,
    columns,
    'quantity',
    '`quantity` INT NOT NULL DEFAULT 1',
    'UPDATE goals SET quantity = 1 WHERE quantity IS NULL OR quantity <= 0',
  );
  await ensureColumn(
    sequelize,
    columns,
    'unit_price',
    '`unit_price` DECIMAL(18,2) NULL',
  );

  await sequelize.query(
    'UPDATE goals SET quantity = 1 WHERE quantity IS NULL OR quantity <= 0',
  );
}

module.exports = { ensureGoalCompatibility };
