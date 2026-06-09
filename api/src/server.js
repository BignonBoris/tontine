const app = require('./app');
const env = require('./config/env');
const { sequelize, models } = require('./database/models');
const runBootstrap = require('./database/bootstrap/run-bootstrap');
const runSeeds = require('./database/seeds/run-seeds');

async function start() {
  try {
    await sequelize.authenticate();
    await runBootstrap(sequelize);
    const shouldSyncSchema = env.sequelizeSync && env.nodeEnv !== 'production';

    if (env.sequelizeSync && env.nodeEnv === 'production') {
      console.warn(
        '[WARN] SEQUELIZE_SYNC ignored in production. Use bootstrap/migrations to avoid schema drift and MySQL index limits.',
      );
    }

    if (shouldSyncSchema) {
      await sequelize.sync();
    }
    const defaultAgent = await runSeeds(models);

    if (env.nodeEnv !== 'production') {
      console.log(
        `Agent par defaut disponible: ${defaultAgent.phoneNumber} / PIN ${defaultAgent.pin} (${defaultAgent.agentCode})`,
      );
    }

    app.listen(env.port, () => {
      console.log(`${env.appName} demarree sur ${env.appBaseUrl}`);
    });
  } catch (error) {
    console.error('Echec de demarrage API:', error);
    process.exit(1);
  }
}

start();
