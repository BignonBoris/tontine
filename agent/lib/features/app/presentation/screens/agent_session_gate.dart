import 'package:agent/core/storage/session_storage.dart';
import 'package:agent/features/auth/presentation/screens/agent_login_screen.dart';
import 'package:agent/features/navigation/presentation/screens/agent_main_shell.dart';
import 'package:flutter/material.dart';

class AgentSessionGate extends StatelessWidget {
  const AgentSessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SessionStorage.hasActiveSession(),
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
