import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
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

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF1A237E);

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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryBlue,
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: "Accueil",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lock_clock_outlined),
              label: "Tontine",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_rounded),
              label: "Coffres",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_rounded),
              label: "Marketplace",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: "Profil",
            ),
          ],
        ),
      ),
    );
  }
}
