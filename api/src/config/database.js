const { Sequelize } = require('sequelize');
const env = require('./env');

const sequelize = new Sequelize(
  env.database.name,
  env.database.user,
  env.database.password,
  {
    host: env.database.host,
    port: env.database.port,
    dialect: 'mysql',
    logging: env.nodeEnv === 'development' ? (msg) => console.log(msg) : false,
    timezone: '+01:00',
    define: {
      underscored: true,
      freezeTableName: true,
    },
  },
);

module.exports = sequelize;
