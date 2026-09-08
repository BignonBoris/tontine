const fs = require('fs');
const path = require('path');

const modelsDir = path.join(__dirname, 'src/database/models');
const bootstrapFile = path.join(__dirname, 'src/database/bootstrap/run-bootstrap.js');
const migrationsDir = path.join(__dirname, 'migrations');

const models = fs.readdirSync(modelsDir).filter(f => f.endsWith('.model.js'));
const bootstrapContent = fs.readFileSync(bootstrapFile, 'utf8');
const migrations = fs.readdirSync(migrationsDir);

console.log('--- Missing from Bootstrap or Migrations ---');
let missingCount = 0;
for (const modelFile of models) {
  const modelNameBase = modelFile.replace('.model.js', '');
  
  // Check if it's in bootstrap (usually named ensureSomethingCompatibility)
  // We'll just check if the model name base is in the bootstrap file (as string)
  const inBootstrap = bootstrapContent.includes(modelNameBase);
  
  // Check if it has a migration (rough string check)
  const hasMigration = migrations.some(m => m.includes(modelNameBase) || m.replace(/-/g, '').includes(modelNameBase.replace(/-/g, '')));
  
  // Specifically check for idempotency
  if (modelNameBase === 'idempotency-key') {
      // It has the migration we just added, so it's fine.
  }

  if (!inBootstrap && !hasMigration && modelNameBase !== 'idempotency-key') {
    console.log(`- ${modelFile}`);
    missingCount++;
  }
}
console.log(`\nTotal missing: ${missingCount}`);
