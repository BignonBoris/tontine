const { Sequelize } = require('sequelize');
const env = require('./env');
require('mysql2'); // Force le bundler de Vercel à inclure mysql2

const sequelize = new Sequelize(
  env.database.name,
  env.database.user,
  env.database.password,
  {
    host: env.database.host,
    port: env.database.port,
    dialect: 'mysql',
    dialectModule: require('mysql2'), // <-- Indispensable pour Vercel
    logging: false,
    timezone: '+01:00',
    define: {
      underscored: true,
      freezeTableName: true,
    },
  },
);

module.exports = sequelize;
