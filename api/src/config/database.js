const { Sequelize } = require('sequelize');
const env = require('./env');
require('mysql2'); // Force le bundler de Vercel à inclure mysql2

const isServerless = Boolean(process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME);

// Options du driver MySQL2 adaptées au réseau et au Serverless
const dialectOptions = {
  connectTimeout: 8000, // 8 secondes max pour négocier la socket TCP
};

if (process.env.DB_SSL === 'true' || process.env.DB_SSL_REJECT_UNAUTHORIZED === 'false') {
  dialectOptions.ssl = {
    rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED === 'true',
  };
}

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
    pool: isServerless
      ? {
          max: 2,        // 2 connexions max par instance Serverless pour ne pas saturer la BDD
          min: 0,
          idle: 0,       // Ne pas conserver de connexions inactives dans une instance gelée
          acquire: 8000, // Timeout d'acquisition à 8s max (au lieu des 60s par défaut de Sequelize)
          evict: 1000,
        }
      : {
          max: 10,
          min: 0,
          idle: 10000,
          acquire: 30000,
        },
    dialectOptions,
    define: {
      underscored: true,
      freezeTableName: true,
    },
  },
);

module.exports = sequelize;
