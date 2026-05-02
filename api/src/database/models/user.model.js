const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const User = sequelize.define(
  'User',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    phoneNumber: {
      type: DataTypes.STRING(32),
      allowNull: false,
      unique: true,
    },
    displayName: {
      type: DataTypes.STRING(120),
      allowNull: false,
      defaultValue: 'Utilisateur maTontine',
    },
    accountType: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'Personnel',
    },
    memberSince: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
    },
    lastLoginAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    },
  },
  { tableName: 'users' },
);

module.exports = User;
