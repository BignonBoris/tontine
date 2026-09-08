const fs = require('fs');
const path = require('path');
const { sequelize, models } = require('./src/database/models');

async function generateMigration() {
  const missingTables = [
    'agent_balance_histories',
    'agent_group_advance_recoveries',
    'agent_group_advances',
    'agent_group_contributions',
    'agent_group_members',
    'agent_group_turns',
    'agent_groups',
    'agent_profiles',
    'audit_logs',
    'auth_otps',
    'available_balance_histories',
    'goal_transactions',
    'goals',
    'market_favorites',
    'market_offers',
    'market_orders',
    'notifications',
    'provisionings',
    'tontine_archives',
    'tontine_cycles',
    'tontine_histories',
    'tontine_kyc_limits',
    'user_preferences',
    'wallets'
  ];

  let migrationCode = `'use strict';\n\nmodule.exports = {\n  up: async (queryInterface, Sequelize) => {\n`;

  for (const tableName of missingTables) {
    // Find the model by tableName
    const model = Object.values(models).find(m => m.tableName === tableName);
    if (!model) {
      console.log('Model not found for table:', tableName);
      continue;
    }

    const attributes = model.getAttributes();
    migrationCode += `    await queryInterface.createTable('${tableName}', {\n`;

    for (const [key, attr] of Object.entries(attributes)) {
      migrationCode += `      ${attr.field || key}: {\n`;
      migrationCode += `        type: Sequelize.${attr.type.key}${attr.type.options ? '(' + JSON.stringify(attr.type.options).replace(/^\{|\}$/g, '') + ')' : ''},\n`;
      if (attr.primaryKey) migrationCode += `        primaryKey: true,\n`;
      if (attr.autoIncrement) migrationCode += `        autoIncrement: true,\n`;
      if (attr.allowNull === false) migrationCode += `        allowNull: false,\n`;
      if (attr.defaultValue !== undefined) {
        if (typeof attr.defaultValue === 'string') {
          migrationCode += `        defaultValue: '${attr.defaultValue}',\n`;
        } else {
          migrationCode += `        defaultValue: ${attr.defaultValue},\n`;
        }
      }
      if (attr.unique) migrationCode += `        unique: true,\n`;
      
      // Handle ENUMs specifically if needed (simplifying for script)
      if (attr.type.key === 'ENUM') {
          const values = attr.type.values.map(v => `'${v}'`).join(', ');
          migrationCode = migrationCode.replace(`Sequelize.ENUM()`, `Sequelize.ENUM(${values})`);
      }
      // Handle string length
      if (attr.type.key === 'STRING' && attr.type._length) {
          migrationCode = migrationCode.replace(`Sequelize.STRING`, `Sequelize.STRING(${attr.type._length})`);
      }

      migrationCode += `      },\n`;
    }
    migrationCode += `    });\n\n`;
  }

  migrationCode += `  },\n\n  down: async (queryInterface, Sequelize) => {\n`;
  for (const tableName of missingTables) {
    migrationCode += `    await queryInterface.dropTable('${tableName}');\n`;
  }
  migrationCode += `  }\n};\n`;

  const filepath = path.join(__dirname, 'migrations', '20260908010000-create-missing-tables.js');
  fs.writeFileSync(filepath, migrationCode);
  console.log('Migration created at:', filepath);
}

generateMigration().catch(console.error).finally(() => process.exit(0));
