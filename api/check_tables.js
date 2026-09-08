const fs = require('fs');
const path = require('path');

const modelsDir = path.join(__dirname, 'src/database/models');
const bootstrapDir = path.join(__dirname, 'src/database/bootstrap');
const migrationsDir = path.join(__dirname, 'migrations');

// 1. Get all tableNames from models
const models = fs.readdirSync(modelsDir).filter(f => f.endsWith('.model.js'));
const tableNames = new Set();
for (const modelFile of models) {
  const content = fs.readFileSync(path.join(modelsDir, modelFile), 'utf8');
  const match = content.match(/tableName:\s*['"`](.*?)['"`]/);
  if (match) {
    tableNames.add(match[1]);
  }
}

// 2. Get all created tables in bootstrap
const createdInBootstrap = new Set();
const bootstrapFiles = fs.readdirSync(bootstrapDir).filter(f => f.endsWith('.js'));
for (const file of bootstrapFiles) {
  const content = fs.readFileSync(path.join(bootstrapDir, file), 'utf8');
  // Look for createTable('table_name', ...)
  const matches = [...content.matchAll(/createTable\s*\(\s*['"`](.*?)['"`]/g)];
  for (const m of matches) {
    createdInBootstrap.add(m[1]);
  }
}

// 3. Get all created tables in migrations
const createdInMigrations = new Set();
const migrationFiles = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.js'));
for (const file of migrationFiles) {
  const content = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
  const matches = [...content.matchAll(/createTable\s*\(\s*['"`](.*?)['"`]/g)];
  for (const m of matches) {
    createdInMigrations.add(m[1]);
  }
}

// 4. Find missing tables
const missingTables = [];
for (const table of tableNames) {
  if (!createdInBootstrap.has(table) && !createdInMigrations.has(table)) {
    missingTables.push(table);
  }
}

console.log('--- Missing Tables ---');
console.log(missingTables.length === 0 ? 'All tables are covered!' : missingTables.join('\n'));
