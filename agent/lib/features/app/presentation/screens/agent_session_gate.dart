import 'package:agent/core/storage/session_storage.dart';
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
