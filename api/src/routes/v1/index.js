const express = require('express');
const authRoutes = require('../../modules/auth/auth.routes');
const agentAuthRoutes = require('../../modules/agent-auth/agent-auth.routes');
const agentClientsRoutes = require('../../modules/agent-clients/agent-clients.routes');
const agentDashboardRoutes = require('../../modules/agent-dashboard/agent-dashboard.routes');
const agentProvisioningsRoutes = require('../../modules/agent-provisionings/agent-provisionings.routes');
const profileRoutes = require('../../modules/profile/profile.routes');
const notificationsRoutes = require('../../modules/notifications/notifications.routes');
const walletRoutes = require('../../modules/wallet/wallet.routes');
const tontineRoutes = require('../../modules/tontine/tontine.routes');
const goalsRoutes = require('../../modules/goals/goals.routes');
const marketplaceRoutes = require('../../modules/marketplace/marketplace.routes');
const dashboardRoutes = require('../../modules/dashboard/dashboard.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/agent/auth', agentAuthRoutes);
router.use('/agent/clients', agentClientsRoutes);
router.use('/agent/dashboard', agentDashboardRoutes);
router.use('/agent/provisionings', agentProvisioningsRoutes);
router.use('/profile', profileRoutes);
router.use('/notifications', notificationsRoutes);
router.use('/wallet', walletRoutes);
router.use('/tontine', tontineRoutes);
router.use('/goals', goalsRoutes);
router.use('/marketplace', marketplaceRoutes);
router.use('/dashboard', dashboardRoutes);

module.exports = router;
