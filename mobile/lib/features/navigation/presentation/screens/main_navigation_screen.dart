import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/services/read_model_bootstrap_service.dart';
import 'package:mobile/core/services/realtime_notification_service.dart';
import 'package:mobile/core/services/update_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/update_dialog.dart';
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
import 'package:mobile/features/auth/data/services/device_approval_service.dart';
import 'package:mobile/features/auth/data/services/biometric_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final bool skipOnboarding;

  const MainNavigationScreen({
    super.key,
    this.skipOnboarding = false,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _requiresUnlockOnResume = false;
  bool _unlockRouteOpen = false;

  StreamSubscription? _realtimeSubscription;
  Timer? _deviceApprovalTimer;
  bool _deviceApprovalDialogOpen = false;
  final DeviceApprovalService _deviceApprovalService = DeviceApprovalService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(PushNotificationService.instance.start());
    unawaited(
      ReadModelBootstrapService.nonInvalidating().warmUpCurrentSession(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingInvitationIfNeeded();
      _pollDeviceApprovalRequests();
      _checkForUpdate();
    });
    _deviceApprovalTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollDeviceApprovalRequests(),
    );

    _realtimeSubscription = RealtimeNotificationService.instance.stream.listen((event) {
      if (event.eventName == 'notification.created') {
        final payload = event.notification;
        final title = payload['title']?.toString() ?? 'Nouvelle alerte';
        final message = payload['message']?.toString() ?? '';
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (message.isNotEmpty) Text(message),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.primaryColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  /// Propose la nouvelle version de l'APK (hors Play Store) si l'API en annonce une.
  Future<void> _checkForUpdate() async {
    final result = await UpdateService.instance.checkOncePerSession();
    if (result == null || !result.updateAvailable || !mounted) return;

    await showDialog<bool>(
      context: context,
      // Obligatoire = non dismissable par tap en dehors
      barrierDismissible: !result.isMandatory,
      builder: (_) => UpdateDialog(result: result),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _deviceApprovalTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Seul « paused » signifie que l'utilisateur a quitté l'app. « inactive »
    // arrive aussi pour le volet de notifications ou une fenêtre de permission.
    if (state == AppLifecycleState.paused) {
      // Ignorer la pause provoquée par l'écran de verrouillage lui-même
      // (fenêtre système empreinte / code du téléphone).
      if (_unlockRouteOpen || BiometricService.isAuthenticationInProgress) {
        return;
      }
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

    final bypassActive =
        await LocalSecurityService.isTemporaryAppLockBypassActive();
    if (!mounted) {
      return;
    }
    if (bypassActive) {
      _requiresUnlockOnResume = false;
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

    final bypassStillActive =
        await LocalSecurityService.isTemporaryAppLockBypassActive();
    if (!mounted) {
      return;
    }
    if (bypassStillActive) {
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

  Future<void> _pollDeviceApprovalRequests() async {
    if (!mounted || _deviceApprovalDialogOpen) return;
    try {
      final requests = await _deviceApprovalService.pending();
      if (!mounted || requests.isEmpty || _deviceApprovalDialogOpen) return;
      final request = Map<String, dynamic>.from(requests.first as Map);
      final requestId = request['id']?.toString() ?? '';
      if (requestId.isEmpty) return;
      _deviceApprovalDialogOpen = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Nouvelle connexion détectée'),
          content: const Text(
            'Une tentative de connexion à votre compte est en cours depuis un autre appareil. Voulez-vous l’autoriser ?',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  await _deviceApprovalService.reject(requestId);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {}
              },
              child: const Text('Refuser'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await _deviceApprovalService.approve(requestId);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {}
              },
              child: const Text('Autoriser'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Feature désactivée ou service momentanément indisponible : ne pas
      // perturber la navigation normale de l'utilisateur.
    } finally {
      _deviceApprovalDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        skipOnboarding: widget.skipOnboarding,
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
        onOpenProfileTab: () {
          setState(() {
            _currentIndex = 4;
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
