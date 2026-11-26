const { DataTypes } = require('sequelize');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

/** Cree la table community_posts (assistant Community Manager) si absente. */
async function ensureCommunityPostCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();
  if (await tableExists(queryInterface, 'community_posts')) {
    return;
  }

  await queryInterface.createTable('community_posts', {
    id: { type: DataTypes.UUID, primaryKey: true, defaultValue: DataTypes.UUIDV4 },
    reference: { type: DataTypes.STRING(32), allowNull: false, unique: true },
    kind: { type: DataTypes.STRING(16), allowNull: false, defaultValue: 'post' },
    network: { type: DataTypes.STRING(16), allowNull: false },
    language: { type: DataTypes.STRING(8), allowNull: false, defaultValue: 'fr' },
    topic: { type: DataTypes.STRING(255), allowNull: true },
    title: { type: DataTypes.STRING(160), allowNull: true },
    content: { type: DataTypes.TEXT, allowNull: false },
    hashtags: { type: DataTypes.JSON, allowNull: true },
    visual_idea: { type: DataTypes.TEXT, allowNull: true },
    call_to_action: { type: DataTypes.STRING(255), allowNull: true },
    source_text: { type: DataTypes.TEXT, allowNull: true },
    category: { type: DataTypes.STRING(32), allowNull: true },
    sentiment: { type: DataTypes.STRING(16), allowNull: true },
    needs_support: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
    support_reason: { type: DataTypes.STRING(255), allowNull: true },
    status: { type: DataTypes.STRING(16), allowNull: false, defaultValue: 'draft' },
    batch_id: { type: DataTypes.UUID, allowNull: true },
    ai_model: { type: DataTypes.STRING(64), allowNull: true },
    created_by: { type: DataTypes.STRING(100), allowNull: true },
    approved_by: { type: DataTypes.STRING(100), allowNull: true },
    approved_at: { type: DataTypes.DATE, allowNull: true },
    published_at: { type: DataTypes.DATE, allowNull: true },
    archived_at: { type: DataTypes.DATE, allowNull: true },
    created_at: { type: DataTypes.DATE, allowNull: false },
    updated_at: { type: DataTypes.DATE, allowNull: false },
  });

  await queryInterface.addIndex('community_posts', ['status']);
  await queryInterface.addIndex('community_posts', ['network']);
  await queryInterface.addIndex('community_posts', ['created_at']);
}

module.exports = { ensureCommunityPostCompatibility };
