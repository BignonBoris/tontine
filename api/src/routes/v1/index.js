const express = require('express');
const authRoutes = require('../../modules/auth/auth.routes');
const profileRoutes = require('../../modules/profile/profile.routes');
const notificationsRoutes = require('../../modules/notifications/notifications.routes');
const walletRoutes = require('../../modules/wallet/wallet.routes');
const tontineRoutes = require('../../modules/tontine/tontine.routes');
const goalsRoutes = require('../../modules/goals/goals.routes');
const marketplaceRoutes = require('../../modules/marketplace/marketplace.routes');
const dashboardRoutes = require('../../modules/dashboard/dashboard.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/profile', profileRoutes);
router.use('/notifications', notificationsRoutes);
router.use('/wallet', walletRoutes);
router.use('/tontine', tontineRoutes);
router.use('/goals', goalsRoutes);
router.use('/marketplace', marketplaceRoutes);
router.use('/dashboard', dashboardRoutes);

module.exports = router;
