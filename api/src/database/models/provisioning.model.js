const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  PROVISIONING_STATUSES,
  PROVISIONING_SOURCES,
} = require('../../common/constants/enums');

const Provisioning = sequelize.define(
  'Provisioning',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    reference: {
      type: DataTypes.STRING(64),
      allowNull: false,
      unique: true,
    },
    agentProfileId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    clientUserId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    source: {
      type: DataTypes.ENUM(...PROVISIONING_SOURCES),
      allowNull: false,
      defaultValue: 'agent',
    },
    status: {
      type: DataTypes.ENUM(...PROVISIONING_STATUSES),
      allowNull: false,
      defaultValue: 'validated',
    },
    notes: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    validatedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    validatedByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    initiatedByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    initiatorType: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
  },
  {
    tableName: 'provisionings',
    indexes: [
      { unique: true, fields: ['reference'] },
      { fields: ['agent_profile_id', 'created_at'] },
      { fields: ['client_user_id', 'created_at'] },
      { fields: ['initiated_by_user_id', 'created_at'] },
      { fields: ['status'] },
    ],
  },
);

module.exports = Provisioning;
