const { DataTypes } = require('sequelize');
const sequelize = require('../../config/database');
const {
  AGENT_GROUP_CONTRIBUTION_STATUSES,
} = require('../../common/constants/enums');

const AgentGroupContribution = sequelize.define(
  'AgentGroupContribution',
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
    memberId: {
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
      type: DataTypes.ENUM(...AGENT_GROUP_CONTRIBUTION_STATUSES),
      allowNull: false,
      defaultValue: 'pending',
    },
    paymentSource: {
      type: DataTypes.STRING(32),
      allowNull: true,
    },
    paidAt: {
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
    tableName: 'agent_group_contributions',
    indexes: [
      { unique: true, fields: ['group_id', 'member_id', 'turn_number'] },
      { fields: ['group_id', 'turn_number', 'status'] },
      { fields: ['member_id', 'status', 'turn_number'] },
      { fields: ['beneficiary_member_id', 'turn_number'] },
    ],
  },
);

module.exports = AgentGroupContribution;
