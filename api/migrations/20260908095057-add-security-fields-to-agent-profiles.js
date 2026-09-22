'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.addColumn('agent_profiles', 'device_id', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await queryInterface.addColumn('agent_profiles', 'force_logout', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    });
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.removeColumn('agent_profiles', 'device_id');
    await queryInterface.removeColumn('agent_profiles', 'force_logout');
  }
};
