const env = require('./env');

module.exports = {
  development: {
    username: env.database.user,
    password: env.database.password,
    database: env.database.name,
    host: env.database.host,
    port: env.database.port,
    dialect: 'mysql',
    define: {
      underscored: true,
      freezeTableName: true,
    }
  },
  test: {
    username: env.database.user,
    password: env.database.password,
    database: env.database.name,
    host: env.database.host,
    port: env.database.port,
    dialect: 'mysql',
    define: {
      underscored: true,
      freezeTableName: true,
    }
  },
  production: {
    username: env.database.user,
    password: env.database.password,
    database: env.database.name,
    host: env.database.host,
    port: env.database.port,
    dialect: 'mysql',
    define: {
      underscored: true,
      freezeTableName: true,
    }
  }
};
