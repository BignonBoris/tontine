const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

/**
 * Brouillon de l'assistant Community Manager : publication pour un reseau,
 * ou reponse proposee a un commentaire/message.
 * Rien n'est publie automatiquement : l'admin valide puis publie lui-meme.
 * Pas de suppression physique : on archive.
 */
const CommunityPost = sequelize.define(
  'CommunityPost',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    reference: {
      type: DataTypes.STRING(32),
      allowNull: false,
      unique: true,
    },
    kind: {
      type: DataTypes.STRING(16),
      allowNull: false,
      defaultValue: 'post',
    },
    network: {
      type: DataTypes.STRING(16),
      allowNull: false,
    },
    language: {
      type: DataTypes.STRING(8),
      allowNull: false,
      defaultValue: 'fr',
    },
    topic: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    title: {
      type: DataTypes.STRING(160),
      allowNull: true,
    },
    content: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    hashtags: {
      type: DataTypes.JSON,
      allowNull: true,
    },
    visualIdea: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    callToAction: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    // Reponses : commentaire d'origine et analyse
    sourceText: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    category: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    sentiment: {
      type: DataTypes.STRING(16),
      allowNull: true,
    },
    needsSupport: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    supportReason: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    status: {
      type: DataTypes.STRING(16),
      allowNull: false,
      defaultValue: 'draft',
    },
    batchId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    aiModel: {
      type: DataTypes.STRING(64),
      allowNull: true,
    },
    createdBy: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    approvedBy: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    approvedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    publishedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    archivedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'community_posts',
    indexes: [{ fields: ['status'] }, { fields: ['network'] }, { fields: ['created_at'] }],
  },
);

module.exports = CommunityPost;
