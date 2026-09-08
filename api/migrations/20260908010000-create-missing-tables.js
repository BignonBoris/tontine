'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('agent_balance_histories', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      agent_profile_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      type: {
        type: Sequelize.ENUM('topUp', 'clientDeposit', 'clientWithdrawal', 'adjustment'),
        allowNull: false,
      },
      reference: {
        type: Sequelize.STRING(64),
        allowNull: false,
        unique: true,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      is_credit: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
      },
      balance_before: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      balance_after: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      label: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      note: {
        type: Sequelize.STRING(255),
      },
      related_entity_type: {
        type: Sequelize.STRING(64),
      },
      related_entity_id: {
        type: Sequelize.STRING(128),
      },
      initiated_by_user_id: {
        type: Sequelize.UUID,
      },
      initiator_type: {
        type: Sequelize.STRING(32),
      },
      occurred_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_group_advance_recoveries', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      advance_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      group_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      contribution_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      beneficiary_member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      agent_profile_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      reference: {
        type: Sequelize.STRING(64),
        allowNull: false,
        unique: true,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      recovered_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_group_advances', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      group_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      contribution_id: {
        type: Sequelize.UUID,
        allowNull: false,
        unique: true,
      },
      member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      beneficiary_member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      agent_profile_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      penalty_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      penalty_paid: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      recovered_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      status: {
        type: Sequelize.ENUM('outstanding', 'partially_recovered', 'recovered', 'escalated'),
        allowNull: false,
        defaultValue: 'outstanding',
      },
      advanced_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      recovered_at: {
        type: Sequelize.DATE,
      },
      last_recovered_at: {
        type: Sequelize.DATE,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_group_contributions', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      group_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      beneficiary_member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      turn_number: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      due_date: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('pending', 'paid', 'cancelled'),
        allowNull: false,
        defaultValue: 'pending',
      },
      payment_source: {
        type: Sequelize.STRING(32),
      },
      paid_at: {
        type: Sequelize.DATE,
      },
      paid_by_agent_profile_id: {
        type: Sequelize.UUID,
      },
      paid_by_user_id: {
        type: Sequelize.UUID,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_group_members', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      group_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      client_user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('requested', 'invited', 'active', 'declined', 'rejected', 'removed'),
        allowNull: false,
        defaultValue: 'invited',
      },
      joined_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      turn_position: {
        type: Sequelize.INTEGER,
      },
      removed_at: {
        type: Sequelize.DATE,
      },
      removal_reason: {
        type: Sequelize.STRING(255),
      },
      added_by_user_id: {
        type: Sequelize.UUID,
      },
      removed_by_user_id: {
        type: Sequelize.UUID,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_group_turns', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      group_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      beneficiary_member_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      turn_number: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      due_date: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      status: {
        type: Sequelize.STRING(32),
        allowNull: false,
        defaultValue: 'collecting',
      },
      payout_method: {
        type: Sequelize.STRING(32),
      },
      payout_at: {
        type: Sequelize.DATE,
      },
      paid_by_agent_profile_id: {
        type: Sequelize.UUID,
      },
      paid_by_user_id: {
        type: Sequelize.UUID,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_groups', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      reference: {
        type: Sequelize.STRING(64),
        allowNull: false,
        unique: true,
      },
      agent_profile_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      name: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      normalized_name: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      description: {
        type: Sequelize.STRING(255),
      },
      participant_count: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      member_count: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0,
      },
      turn_interval_value: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      turn_interval_unit: {
        type: Sequelize.ENUM('day', 'week', 'month'),
        allowNull: false,
      },
      contribution_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      commission_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      planned_start_date: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      launch_status: {
        type: Sequelize.ENUM('collecting', 'ready', 'started', 'launch_cancelled'),
        allowNull: false,
        defaultValue: 'collecting',
      },
      started_at: {
        type: Sequelize.DATE,
      },
      launch_cancelled_at: {
        type: Sequelize.DATE,
      },
      launch_cancellation_reason: {
        type: Sequelize.STRING(255),
      },
      status: {
        type: Sequelize.ENUM('active', 'suspended'),
        allowNull: false,
        defaultValue: 'active',
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('agent_profiles', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
        unique: true,
      },
      agent_code: {
        type: Sequelize.STRING(32),
        allowNull: false,
        unique: true,
      },
      pin_hash: {
        type: Sequelize.STRING(128),
        allowNull: false,
      },
      full_name: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      agent_balance: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      is_active: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('audit_logs', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
      },
      action: {
        type: Sequelize.STRING(120),
        allowNull: false,
      },
      entity_type: {
        type: Sequelize.STRING(64),
        allowNull: false,
      },
      entity_id: {
        type: Sequelize.STRING(128),
      },
      status: {
        type: Sequelize.STRING(32),
        allowNull: false,
        defaultValue: 'success',
      },
      ip_address: {
        type: Sequelize.STRING(64),
      },
      user_agent: {
        type: Sequelize.STRING(255),
      },
      metadata: {
        type: Sequelize.JSON,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('auth_otps', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      phone_number: {
        type: Sequelize.STRING(32),
        allowNull: false,
      },
      purpose: {
        type: Sequelize.ENUM('register', 'login'),
        allowNull: false,
      },
      code: {
        type: Sequelize.STRING(8),
        allowNull: false,
      },
      attempt_count: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0,
      },
      resend_count: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0,
      },
      last_sent_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      blocked_until: {
        type: Sequelize.DATE,
      },
      expires_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      consumed_at: {
        type: Sequelize.DATE,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('available_balance_histories', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      type: {
        type: Sequelize.ENUM('tontinePayout', 'tontineEarlyStop', 'tontineBonus', 'withdrawalRequested', 'withdrawalReleased', 'withdrawalPaid', 'goalFunding', 'tontineFunding', 'tontineFundingReversal', 'groupContribution'),
        allowNull: false,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      label: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      is_credit: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
      },
      reversal_of_history_id: {
        type: Sequelize.UUID,
      },
      occurred_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('goal_transactions', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      goal_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      title: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      is_deposit: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
      },
      occurred_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('goals', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      linked_offer_id: {
        type: Sequelize.STRING(64),
      },
      quantity: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      unit_price: {
        type: Sequelize.DECIMAL(18, 2),
      },
      title: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      target_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      current_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      icon_code_point: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      color_value: {
        type: Sequelize.BIGINT,
        allowNull: false,
      },
      is_priority: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      status: {
        type: Sequelize.ENUM('active', 'closed'),
        allowNull: false,
        defaultValue: 'active',
      },
      start_date: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      end_date: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('market_favorites', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      offer_id: {
        type: Sequelize.STRING(64),
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('market_offers', {
      id: {
        type: Sequelize.STRING(64),
        primaryKey: true,
      },
      title: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: false,
      },
      description_html: {
        type: Sequelize.TEXT,
      },
      image_url: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      category: {
        type: Sequelize.STRING(80),
        allowNull: false,
      },
      price: {
        type: Sequelize.DECIMAL(18, 2),
      },
      brand: {
        type: Sequelize.STRING(120),
      },
      is_active: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('market_orders', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      offer_id: {
        type: Sequelize.STRING(64),
        allowNull: false,
      },
      title: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      quantity: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      unit_price: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('pending', 'confirmed', 'ready', 'completed', 'cancelled'),
        allowNull: false,
        defaultValue: 'pending',
      },
      ordered_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_status_at: {
        type: Sequelize.DATE,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('notifications', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      type: {
        type: Sequelize.ENUM('deposit', 'cycle', 'goal', 'marketplace', 'system'),
        allowNull: false,
        defaultValue: 'system',
      },
      title: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      message: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      is_read: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      created_at_client: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('provisionings', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      sync_id: {
        type: Sequelize.UUID,
        unique: true,
      },
      reference: {
        type: Sequelize.STRING(64),
        allowNull: false,
        unique: true,
      },
      agent_profile_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      client_user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      cycle_id: {
        type: Sequelize.UUID,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      source: {
        type: Sequelize.ENUM('agent', 'mobile_money'),
        allowNull: false,
        defaultValue: 'agent',
      },
      status: {
        type: Sequelize.ENUM('initiated', 'pending_validation', 'validated', 'rejected', 'cancelled'),
        allowNull: false,
        defaultValue: 'validated',
      },
      notes: {
        type: Sequelize.STRING(255),
      },
      validated_at: {
        type: Sequelize.DATE,
      },
      validated_by_user_id: {
        type: Sequelize.UUID,
      },
      reversed_at: {
        type: Sequelize.DATE,
      },
      reversed_by_user_id: {
        type: Sequelize.UUID,
      },
      reversal_reason: {
        type: Sequelize.STRING(255),
      },
      initiated_by_user_id: {
        type: Sequelize.UUID,
      },
      initiator_type: {
        type: Sequelize.STRING(32),
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('tontine_archives', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      stake_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      target_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      cumulative_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      commission_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      net_payout_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('completed', 'stoppedEarly'),
        allowNull: false,
      },
      started_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      expected_end_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      ended_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('tontine_cycles', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      stake_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      cumulative_amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      status: {
        type: Sequelize.ENUM('nonConfiguree', 'active', 'enAttenteValidationFin', 'terminee', 'arretee'),
        allowNull: false,
        defaultValue: 'nonConfiguree',
      },
      started_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      expected_end_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      ended_at: {
        type: Sequelize.DATE,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('tontine_histories', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      sync_id: {
        type: Sequelize.UUID,
        unique: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
      },
      cycle_id: {
        type: Sequelize.UUID,
      },
      type: {
        type: Sequelize.ENUM('configuration', 'deposit', 'depositReversal', 'cycleCompleted', 'payoutConfirmed', 'earlyStop', 'restarted'),
        allowNull: false,
      },
      payment_source: {
        type: Sequelize.STRING(32),
      },
      linked_provisioning_id: {
        type: Sequelize.UUID,
      },
      available_balance_history_id: {
        type: Sequelize.UUID,
      },
      reversal_of_history_id: {
        type: Sequelize.UUID,
      },
      amount: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
      },
      label: {
        type: Sequelize.STRING(160),
        allowNull: false,
      },
      note: {
        type: Sequelize.STRING(255),
      },
      initiated_by_user_id: {
        type: Sequelize.UUID,
      },
      initiator_type: {
        type: Sequelize.STRING(32),
      },
      occurred_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('tontine_kyc_limits', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      kyc_status: {
        type: Sequelize.STRING(32),
        allowNull: false,
        unique: true,
      },
      tier_level: {
        type: Sequelize.STRING(32),
        allowNull: false,
        defaultValue: 'tier_0',
      },
      label: {
        type: Sequelize.STRING(120),
        allowNull: false,
      },
      description: {
        type: Sequelize.STRING(255),
      },
      max_daily_stake: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 2000,
      },
      max_cycle_cumulative: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 62000,
      },
      allow_multiple_cycles: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      enabled: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
      updated_by: {
        type: Sequelize.STRING(100),
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('user_preferences', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
        unique: true,
      },
      deposit_notifications_enabled: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
      cycle_notifications_enabled: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      },
      marketing_notifications_enabled: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      pin_enabled: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      biometric_enabled: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      pin_code: {
        type: Sequelize.STRING(128),
      },
      onboarding_goals_done: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

    await queryInterface.createTable('wallets', {
      id: {
        type: Sequelize.UUID,
        primaryKey: true,
      },
      user_id: {
        type: Sequelize.UUID,
        allowNull: false,
        unique: true,
      },
      available_balance: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      reserved_withdrawal_balance: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      tontine_balance: {
        type: Sequelize.DECIMAL(18, 2),
        allowNull: false,
        defaultValue: 0,
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
      },
    });

  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('agent_balance_histories');
    await queryInterface.dropTable('agent_group_advance_recoveries');
    await queryInterface.dropTable('agent_group_advances');
    await queryInterface.dropTable('agent_group_contributions');
    await queryInterface.dropTable('agent_group_members');
    await queryInterface.dropTable('agent_group_turns');
    await queryInterface.dropTable('agent_groups');
    await queryInterface.dropTable('agent_profiles');
    await queryInterface.dropTable('audit_logs');
    await queryInterface.dropTable('auth_otps');
    await queryInterface.dropTable('available_balance_histories');
    await queryInterface.dropTable('goal_transactions');
    await queryInterface.dropTable('goals');
    await queryInterface.dropTable('market_favorites');
    await queryInterface.dropTable('market_offers');
    await queryInterface.dropTable('market_orders');
    await queryInterface.dropTable('notifications');
    await queryInterface.dropTable('provisionings');
    await queryInterface.dropTable('tontine_archives');
    await queryInterface.dropTable('tontine_cycles');
    await queryInterface.dropTable('tontine_histories');
    await queryInterface.dropTable('tontine_kyc_limits');
    await queryInterface.dropTable('user_preferences');
    await queryInterface.dropTable('wallets');
  }
};
