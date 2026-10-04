import 'dart:async';

import 'package:agent/core/security/pin_service.dart';
import 'package:agent/core/storage/session_storage.dart';
import 'package:agent/features/auth/data/services/agent_auth_service.dart';
import 'package:agent/features/auth/presentation/screens/agent_login_screen.dart';
import 'package:agent/features/auth/presentation/screens/pin_lock_screen.dart';
import 'package:flutter/material.dart';

/// Wrapper racine qui gère l'auto-lock de l'application.
///
/// Comportement :
/// - Si l'app passe en arrière-plan et revient après [_timeoutMinutes] minutes,
///   elle affiche l'écran PIN si un agent est connecté.
/// - Si le PIN est validé → l'application reprend normalement.
/// - Si l'agent clique "Changer de compte" ou en cas de force logout →
///   retour à l'écran de connexion complet.
class AutoLockWrapper extends StatefulWidget {
  final Widget child;

  const AutoLockWrapper({super.key, required this.child});

  @override
  State<AutoLockWrapper> createState() => _AutoLockWrapperState();
}

class _AutoLockWrapperState extends State<AutoLockWrapper>
    with WidgetsBindingObserver {
  DateTime? _pausedTime;
  bool _isLocked = false;
  final AgentAuthService _authService = AgentAuthService();
  int _timeoutMinutes = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimeout();
  }

  Future<void> _loadTimeout() async {
    _timeoutMinutes = await _authService.getAutoLockTimeoutMinutes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    final token = await SessionStorage.getToken();
    if (token == null) {
      // Pas connecté, pas de verrouillage nécessaire
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedTime ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedTime != null) {
        final duration = DateTime.now().difference(_pausedTime!);
        if (duration.inMinutes >= _timeoutMinutes) {
          if (mounted) {
            setState(() => _isLocked = true);
          }
        }
        _pausedTime = null;
      }
    }
  }

  void _unlock() {
    if (mounted) {
      setState(() => _isLocked = false);
    }
  }

  void _forceLogout() async {
    await SessionStorage.clear();
    await PinService.clearPin();
    if (mounted) {
      setState(() => _isLocked = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AgentLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PinLockScreen(
          onUnlocked: _unlock,
          onForceLogout: _forceLogout,
        ),
      );
    }
    return widget.child;
  }
}
