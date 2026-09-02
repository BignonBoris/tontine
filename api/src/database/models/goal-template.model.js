const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

/**
 * Modele de coffre par defaut propose a l'onboarding.
 * Gere par l'administration (CRUD), consomme par le mobile apres creation
 * de compte : le client choisit 1 a 3 modeles qui deviennent ses coffres.
 */
const GoalTemplate = sequelize.define(
  'GoalTemplate',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    label: {
      type: DataTypes.STRING(160),
      allowNull: false,
      validate: {
        notEmpty: true,
        len: [3, 160],
      },
    },
    description: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    iconCodePoint: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    colorValue: {
      type: DataTypes.BIGINT,
      allowNull: false,
    },
    defaultTargetAmount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: true,
      validate: {
        min: 0,
      },
    },
    sortOrder: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  { tableName: 'goal_templates' },
);

module.exports = GoalTemplate;
