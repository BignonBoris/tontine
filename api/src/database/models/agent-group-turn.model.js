const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');

const AgentGroupTurn = sequelize.define(
  'AgentGroupTurn',
  {
    id: {
      type: DataTypes.UUID,
      primaryKey: true,
      defaultValue: DataTypes.UUIDV4,
    },
    groupId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    beneficiaryMemberId: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    turnNumber: {
      type: DataTypes.INTEGER,
      allowNull: false,
      validate: {
        min: 1,
      },
    },
    dueDate: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    amount: {
      type: DataTypes.DECIMAL(18, 2),
      allowNull: false,
      validate: {
        min: 0.01,
      },
    },
    status: {
      type: DataTypes.STRING(32),
      allowNull: false,
      defaultValue: 'collecting',
    },
    payoutMethod: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    payoutAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    paidByAgentProfileId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    paidByUserId: {
      type: DataTypes.UUID,
      allowNull: true,
    },
  },
  {
    tableName: 'agent_group_turns',
    indexes: [
      { unique: true, fields: ['group_id', 'turn_number'] },
      { fields: ['group_id', 'status', 'turn_number'] },
      { fields: ['beneficiary_member_id', 'turn_number'] },
    ],
  },
);

module.exports = AgentGroupTurn;
