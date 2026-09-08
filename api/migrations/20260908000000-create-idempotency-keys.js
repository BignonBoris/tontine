'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('idempotency_keys', {
      key: {
        type: Sequelize.STRING(255),
        primaryKey: true,
        allowNull: false,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: true,
      },
      path: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      request_body: {
        type: Sequelize.JSON,
        allowNull: true,
      },
      response_body: {
        type: Sequelize.JSON,
        allowNull: true,
      },
      response_code: {
        type: Sequelize.INTEGER,
        allowNull: true,
      },
      status: {
        type: Sequelize.ENUM('PROCESSING', 'COMPLETED', 'ERROR'),
        allowNull: false,
        defaultValue: 'PROCESSING',
      },
      expires_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        allowNull: false,
        type: Sequelize.DATE,
      },
      updated_at: {
        allowNull: false,
        type: Sequelize.DATE,
      }
    });

    await queryInterface.addIndex('idempotency_keys', ['expires_at']);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('idempotency_keys');
  }
};
