'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('device_sessions', {
      id: { type: Sequelize.UUID, primaryKey: true, allowNull: false },
      user_id: { type: Sequelize.UUID, allowNull: false },
      device_id: { type: Sequelize.STRING(128), allowNull: false },
      status: { type: Sequelize.ENUM('active', 'revoked'), allowNull: false, defaultValue: 'active' },
      last_seen_at: { type: Sequelize.DATE, allowNull: false },
      revoked_at: { type: Sequelize.DATE, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.NOW },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.NOW },
    });
    await queryInterface.addIndex('device_sessions', ['user_id', 'status']);
  },
  async down(queryInterface) {
    await queryInterface.dropTable('device_sessions');
  },
};
