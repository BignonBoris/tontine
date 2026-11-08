'use strict';

/**
 * Allow one client account and one agent account to share a phone number,
 * while keeping duplicate accounts of the same type impossible.
 *
 * This migration changes indexes only. It does not create, merge, or modify
 * any user records.
 */
module.exports = {
  up: async (queryInterface) => {
    const indexes = await queryInterface.showIndex('users');
    const phoneUniqueIndexes = indexes.filter((index) => {
      const fields = (index.fields || []).map((field) => field.attribute || field.name);
      return index.unique && fields.length === 1 && fields[0] === 'phone_number';
    });

    for (const index of phoneUniqueIndexes) {
      await queryInterface.removeIndex('users', index.name);
    }

    const hasCompositeIndex = indexes.some((index) => {
      const fields = (index.fields || []).map((field) => field.attribute || field.name);
      return index.unique && fields.length === 2 && fields.includes('phone_number') && fields.includes('account_type');
    });

    if (!hasCompositeIndex) {
      await queryInterface.addIndex('users', ['phone_number', 'account_type'], {
        name: 'users_phone_number_account_type_unique',
        unique: true,
      });
    }
  },

  down: async (queryInterface) => {
    await queryInterface.removeIndex(
      'users',
      'users_phone_number_account_type_unique',
    );
    await queryInterface.addIndex('users', ['phone_number'], {
      name: 'users_phone_number_unique',
      unique: true,
    });
  },
};
