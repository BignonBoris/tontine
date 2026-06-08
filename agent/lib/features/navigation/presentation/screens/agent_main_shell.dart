import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/storage/agent_navigation_storage.dart';
import 'package:agent/features/clients/presentation/screens/clients_screen.dart';
import 'package:agent/features/groups/presentation/screens/groups_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _restoreLastTab();
  }

  void _goToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    AgentNavigationStorage.saveLastTabIndex(index);
  }

  Future<void> _restoreLastTab() async {
    final lastIndex = await AgentNavigationStorage.getLastTabIndex();
    if (!mounted || lastIndex == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = lastIndex.clamp(0, 4).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      AgentHomeScreen(
        onOpenClients: () => _goToTab(1),
        onOpenProvisioning: () => _goToTab(2),
        onOpenHistory: () => _goToTab(4),
      ),
      const ClientsScreen(),
      const ProvisioningScreen(),
      const GroupsScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        selectedItemColor: AgentAppTheme.primaryColor,
        unselectedItemColor: const Color(0xFF98A2B3),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
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
            label: 'Operations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_2_outlined),
            label: 'Groupes',
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
