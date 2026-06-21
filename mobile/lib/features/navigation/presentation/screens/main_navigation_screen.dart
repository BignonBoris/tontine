import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/services/read_model_bootstrap_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/groups/presentation/screens/group_invitation_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/goals_list_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/marketplace_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/profile_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/tontine_detail_screen.dart';
import 'package:mobile/features/security/presentation/screens/app_unlock_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _requiresUnlockOnResume = false;
  bool _unlockRouteOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(PushNotificationService.instance.start());
    unawaited(ReadModelBootstrapService().warmUpCurrentSession());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingInvitationIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _requiresUnlockOnResume = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _requiresUnlockOnResume) {
      _showUnlockScreenIfNeeded();
    }
  }

  Future<void> _showUnlockScreenIfNeeded() async {
    if (!mounted || _unlockRouteOpen) {
      return;
    }

    final appLockEnabled = await LocalSecurityService.hasAppLockEnabled();
    if (!mounted) {
      return;
    }

    _requiresUnlockOnResume = false;
    if (!appLockEnabled) {
      return;
    }

    _unlockRouteOpen = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const AppUnlockScreen(replaceStack: false),
      ),
    );
    _unlockRouteOpen = false;
  }

  Future<void> _openPendingInvitationIfNeeded() async {
    if (!mounted) {
      return;
    }
    final token = await SessionStorage.getPendingGroupInvitationToken();
    if (!mounted || token == null || token.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupInvitationScreen(
          token: token,
          launchedFromPending: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onOpenMarketplaceTab: () {
          setState(() {
            _currentIndex = 3;
          });
        },
        onOpenTontineTab: () {
          setState(() {
            _currentIndex = 1;
          });
        },
      ),
      const TontineDetailScreen(showBackButton: false),
      const GoalsListScreen(),
      const MarketplaceScreen(showBackButton: false),
      const ProfileScreen(),
    ];

    return BlocProvider(
      create: (context) => DashboardBloc()..add(LoadDashboardData()),
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            final unreadCount = state is DashboardLoaded
                ? state.notifications.where((item) => !item.isRead).length
                : 0;

            return BottomNavigationBar(
              currentIndex: _currentIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.primaryColor,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: "Accueil",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.lock_clock_outlined),
                  label: "Tontine",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: "Coffres",
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_rounded),
                  label: "Marketplace",
                ),
                BottomNavigationBarItem(
                  icon: _NavBadgeIcon(
                    icon: Icons.person_rounded,
                    badgeCount: unreadCount,
                  ),
                  label: "Profil",
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavBadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;

  const _NavBadgeIcon({
    required this.icon,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
