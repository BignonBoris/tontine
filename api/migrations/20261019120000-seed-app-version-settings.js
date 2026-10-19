'use strict';

/**
 * Paramètres de version des apps mobiles (mises à jour hors Play Store).
 * Modifiables ensuite depuis l'admin : PUT /api/v1/admin/settings/APP_VERSION_AGENT
 * (ou APP_VERSION_CLIENT) avec { "value": { ... } }.
 * build 1 + download_url vide = aucune mise à jour proposée tant qu'une release n'est pas publiée.
 */
const KEYS = ['APP_VERSION_AGENT', 'APP_VERSION_CLIENT'];

const defaultValue = {
  version: '1.0.0',
  build: 1,
  min_build: 1,
  mandatory: false,
  download_url: '',
  release_notes: '',
  released_at: '',
};

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface) {
    const [existing] = await queryInterface.sequelize.query(
      'SELECT `key` FROM system_settings WHERE `key` IN (:keys)',
      { replacements: { keys: KEYS } },
    );
    const existingKeys = new Set(existing.map((row) => row.key));
    const now = new Date();
    const rows = [
      {
        key: 'APP_VERSION_AGENT',
        description: "Version publiée de l'app Agent (mise à jour APK hors Play Store)",
      },
      {
        key: 'APP_VERSION_CLIENT',
        description: "Version publiée de l'app Client (mise à jour APK hors Play Store)",
      },
    ]
      .filter((row) => !existingKeys.has(row.key))
      .map((row) => ({
        ...row,
        value: JSON.stringify(defaultValue),
        created_at: now,
        updated_at: now,
      }));

    if (rows.length) {
      await queryInterface.bulkInsert('system_settings', rows);
    }
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('system_settings', { key: KEYS });
  },
};
