import 'package:agent/features/clients/presentation/screens/clients_screen.dart';
import 'package:agent/features/history/presentation/screens/history_screen.dart';
import 'package:agent/features/home/presentation/screens/agent_home_screen.dart';
import 'package:agent/features/provisioning/presentation/screens/provisioning_screen.dart';
import 'package:flutter/material.dart';

class AgentMainShell extends StatefulWidget {
  const AgentMainShell({super.key});

  @override
  State<AgentMainShell> createState() => _AgentMainShellState();
}

class _AgentMainShellState extends State<AgentMainShell> {
  int _currentIndex = 0;

  void _goToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      AgentHomeScreen(
        onOpenClients: () => _goToTab(1),
        onOpenProvisioning: () => _goToTab(2),
        onOpenHistory: () => _goToTab(3),
      ),
      const ClientsScreen(),
      const ProvisioningScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.space_dashboard_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Clients',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_card_rounded),
            label: 'Opérations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
