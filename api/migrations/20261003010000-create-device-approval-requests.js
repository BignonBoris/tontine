'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('device_approval_requests', {
      id: { type: Sequelize.UUID, primaryKey: true, allowNull: false },
      user_id: { type: Sequelize.UUID, allowNull: false },
      requesting_device_id: { type: Sequelize.STRING(128), allowNull: false },
      current_session_id: { type: Sequelize.UUID, allowNull: true },
      status: {
        type: Sequelize.ENUM('pending', 'approved', 'rejected', 'expired'),
        allowNull: false,
        defaultValue: 'pending',
      },
      expires_at: { type: Sequelize.DATE, allowNull: false },
      responded_at: { type: Sequelize.DATE, allowNull: true },
      approved_by_device_id: { type: Sequelize.STRING(128), allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.NOW },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.NOW },
    });
    await queryInterface.addIndex('device_approval_requests', ['user_id', 'status']);
    await queryInterface.addIndex('device_approval_requests', ['user_id', 'created_at']);
  },
  async down(queryInterface) {
    await queryInterface.dropTable('device_approval_requests');
  },
};
