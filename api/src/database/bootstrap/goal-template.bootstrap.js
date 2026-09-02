const { DataTypes } = require('sequelize');

async function tableExists(queryInterface, tableName) {
  try {
    await queryInterface.describeTable(tableName);
    return true;
  } catch (_) {
    return false;
  }
}

/**
 * Compatibilite pour l'onboarding "coffres par defaut" :
 * - cree la table goal_templates si sequelize.sync ne l'a pas deja fait ;
 * - ajoute le flag onboarding_goals_done sur user_preferences si absent.
 */
async function ensureGoalTemplateCompatibility(sequelize) {
  const queryInterface = sequelize.getQueryInterface();

  if (!(await tableExists(queryInterface, 'goal_templates'))) {
    await queryInterface.createTable('goal_templates', {
      id: {
        type: DataTypes.UUID,
        primaryKey: true,
        defaultValue: DataTypes.UUIDV4,
      },
      label: { type: DataTypes.STRING(160), allowNull: false },
      description: { type: DataTypes.STRING(255), allowNull: true },
      icon_code_point: { type: DataTypes.INTEGER, allowNull: false },
      color_value: { type: DataTypes.BIGINT, allowNull: false },
      default_target_amount: { type: DataTypes.DECIMAL(18, 2), allowNull: true },
      sort_order: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
      is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
      created_at: { type: DataTypes.DATE, allowNull: false },
      updated_at: { type: DataTypes.DATE, allowNull: false },
    });
  }

  try {
    const columns = await queryInterface.describeTable('user_preferences');
    if (!columns.onboarding_goals_done) {
      await queryInterface.addColumn('user_preferences', 'onboarding_goals_done', {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      });
    }
  } catch (_) {
    // Table user_preferences absente : sequelize.sync la creera complete.
  }
}

module.exports = { ensureGoalTemplateCompatibility };
