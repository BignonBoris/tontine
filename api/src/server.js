const app = require('./app');
const env = require('./config/env');
const { sequelize, models } = require('./database/models');
const runBootstrap = require('./database/bootstrap/run-bootstrap');
const runSeeds = require('./database/seeds/run-seeds');

async function start() {
  try {
    await sequelize.authenticate();
    await runBootstrap(sequelize);
    const isRenderDeployment = Boolean(
      process.env.RENDER ||
        process.env.RENDER_SERVICE_ID ||
        process.env.RENDER_EXTERNAL_URL,
    );
    const shouldSyncSchema =
      env.sequelizeSync &&
      env.nodeEnv === 'development' &&
      !isRenderDeployment;

    if (env.sequelizeSync && !shouldSyncSchema) {
      console.warn(
        '[WARN] SEQUELIZE_SYNC ignored outside local development. Use bootstrap/migrations to avoid schema drift and MySQL index limits.',
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
