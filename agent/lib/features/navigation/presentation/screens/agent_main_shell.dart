import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/storage/agent_navigation_storage.dart';
import 'package:agent/features/clients/presentation/screens/clients_screen.dart';
import 'package:agent/features/groups/presentation/screens/groups_screen.dart';
import 'package:agent/features/profile/presentation/screens/profile_screen.dart';
import 'package:agent/features/home/presentation/screens/agent_home_screen.dart';
import 'package:agent/features/provisioning/presentation/screens/operations_shell_screen.dart';
import 'package:flutter/material.dart';

class AgentMainShell extends StatefulWidget {
  const AgentMainShell({super.key});

  @override
  State<AgentMainShell> createState() => _AgentMainShellState();
}

class _AgentMainShellState extends State<AgentMainShell> {
  int _currentIndex = 0;

  void _goToOperationsTab() {
    setState(() {
      _currentIndex = 2; // Operations shell is index 2
    });
    AgentNavigationStorage.saveLastTabIndex(2);
  }

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
        onOpenProvisioning: _goToOperationsTab,
        onOpenHistory: _goToOperationsTab,
      ),
      const ClientsScreen(),
      const OperationsShellScreen(),
      const GroupsScreen(),
      const ProfileScreen(),
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
            label: 'Opérations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_2_outlined),
            label: 'Groupes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Mon Compte',
          ),
        ],
      ),
    );
  }
}
