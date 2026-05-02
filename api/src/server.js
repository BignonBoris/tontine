const app = require('./app');
const env = require('./config/env');
const { sequelize, models } = require('./database/models');
const runBootstrap = require('./database/bootstrap/run-bootstrap');
const runSeeds = require('./database/seeds/run-seeds');

async function start() {
  try {
    await sequelize.authenticate();
    await runBootstrap(sequelize);
    if (env.sequelizeSync) {
      await sequelize.sync({ alter: env.nodeEnv === 'development' });
    }
    await runSeeds(models);

    app.listen(env.port, () => {
      console.log(`${env.appName} demarree sur ${env.appBaseUrl}`);
    });
  } catch (error) {
    console.error('Echec de demarrage API:', error);
    process.exit(1);
  }
}

start();
