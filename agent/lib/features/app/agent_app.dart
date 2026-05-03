import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/features/app/presentation/screens/agent_session_gate.dart';
import 'package:agent/features/auth/presentation/screens/agent_login_screen.dart';
import 'package:agent/features/navigation/presentation/screens/agent_main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AgentApp extends StatelessWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'maTontine Agent',
      debugShowCheckedModeBanner: false,
      theme: AgentAppTheme.lightTheme,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AgentSessionGate(),
      routes: {
        '/login': (context) => const AgentLoginScreen(),
        '/home': (context) => const AgentMainShell(),
      },
    );
  }
}
