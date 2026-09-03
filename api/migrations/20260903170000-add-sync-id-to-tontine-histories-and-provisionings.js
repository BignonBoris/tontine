'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      const tontineHistories = await queryInterface.describeTable('tontine_histories');
      if (!tontineHistories.sync_id) {
        await queryInterface.addColumn('tontine_histories', 'sync_id', {
          type: Sequelize.UUID,
          allowNull: true,
          unique: true,
        });
      }
    } catch (_) {}

    try {
      const provisionings = await queryInterface.describeTable('provisionings');
      if (!provisionings.sync_id) {
        await queryInterface.addColumn('provisionings', 'sync_id', {
          type: Sequelize.UUID,
          allowNull: true,
          unique: true,
        });
      }
    } catch (_) {}
  },

  async down(queryInterface) {
    try {
      await queryInterface.removeColumn('tontine_histories', 'sync_id');
    } catch (_) {}
    try {
      await queryInterface.removeColumn('provisionings', 'sync_id');
    } catch (_) {}
  },
};
