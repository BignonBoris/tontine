const { DataTypes } = require('sequelize');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

async function ensureColumn(queryInterface, columns, columnName, spec) {
  if (columns[columnName]) {
    return;
  }

  await queryInterface.addColumn('push_device_tokens', columnName, spec);
}

async function ensureIndex(queryInterface, indexName, fields, unique = false) {
  const indexes = await queryInterface.showIndex('push_device_tokens');
  if (indexes.some((index) => index.name === indexName)) {
    return;
  }

  await queryInterface.addIndex('push_device_tokens', {
    name: indexName,
    fields,
    unique,
  });
}

async function ensurePushDeviceTokenCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  const exists = await tableExists(queryInterface, 'push_device_tokens');

  if (!exists) {
    await queryInterface.createTable('push_device_tokens', {
      id: {
        type: DataTypes.UUID,
        primaryKey: true,
        allowNull: false,
      },
      user_id: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      token: {
        type: DataTypes.STRING(255),
        allowNull: false,
      },
      platform: {
        type: DataTypes.STRING(32),
        allowNull: false,
        defaultValue: 'unknown',
      },
      app_name: {
        type: DataTypes.STRING(32),
        allowNull: false,
        defaultValue: 'mobile',
      },
      device_id: {
        type: DataTypes.STRING(128),
        allowNull: true,
      },
      is_active: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
      last_seen_at: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      updated_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    });
  }

  const columns = await queryInterface.describeTable('push_device_tokens');
  await ensureColumn(queryInterface, columns, 'platform', {
    type: DataTypes.STRING(32),
    allowNull: false,
    defaultValue: 'unknown',
  });
  await ensureColumn(queryInterface, columns, 'app_name', {
    type: DataTypes.STRING(32),
    allowNull: false,
    defaultValue: 'mobile',
  });
  await ensureColumn(queryInterface, columns, 'device_id', {
    type: DataTypes.STRING(128),
    allowNull: true,
  });
  await ensureColumn(queryInterface, columns, 'is_active', {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: true,
  });
  await ensureColumn(queryInterface, columns, 'last_seen_at', {
    type: DataTypes.DATE,
    allowNull: true,
  });

  await ensureIndex(
    queryInterface,
    'uq_push_device_tokens_token',
    ['token'],
    true,
  );
  await ensureIndex(
    queryInterface,
    'idx_push_device_tokens_user_active_updated',
    ['user_id', 'is_active', 'updated_at'],
  );
  await ensureIndex(
    queryInterface,
    'idx_push_device_tokens_user_app',
    ['user_id', 'app_name'],
  );
}

module.exports = { ensurePushDeviceTokenCompatibility };
