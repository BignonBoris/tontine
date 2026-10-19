import 'dart:io';

import 'package:agent/core/services/update_service.dart';
import 'package:agent/core/storage/session_storage.dart';
import 'package:agent/core/widgets/update_dialog.dart';
import 'package:agent/features/auth/presentation/screens/agent_login_screen.dart';
import 'package:agent/features/navigation/presentation/screens/agent_main_shell.dart';
import 'package:flutter/material.dart';

class AgentSessionGate extends StatefulWidget {
  const AgentSessionGate({super.key});

  @override
  State<AgentSessionGate> createState() => _AgentSessionGateState();
}

class _AgentSessionGateState extends State<AgentSessionGate> {
  late Future<bool> _hasSessionFuture;

  @override
  void initState() {
    super.initState();
    _hasSessionFuture = SessionStorage.hasActiveSession();
    // Vérification de mise à jour au démarrage (en parallèle)
    _checkForUpdateAfterBuild();
  }

  /// Lance la vérification de version après que le premier frame soit rendu
  void _checkForUpdateAfterBuild() {
    // On attend que le widget soit monté pour pouvoir afficher un dialog
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Uniquement sur Android (les APK s'installent sur Android)
      if (!Platform.isAndroid) return;

      final result = await UpdateService.instance.checkForUpdate();
      if (result == null || !result.updateAvailable) return;
      if (!mounted) return;

      await showDialog<bool>(
        context: context,
        // Obligatoire = non dismissable par tap en dehors
        barrierDismissible: !result.isMandatory,
        builder: (_) => UpdateDialog(result: result),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasSessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data ?? false) {
          return const AgentMainShell();
        }

        return const AgentLoginScreen();
      },
    );
  }
}
