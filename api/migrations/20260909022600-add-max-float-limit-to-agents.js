'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('agent_profiles', 'max_float_limit', {
      type: Sequelize.DECIMAL(18, 2),
      allowNull: false,
      defaultValue: 500000.00,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('agent_profiles', 'max_float_limit');
  },
};
