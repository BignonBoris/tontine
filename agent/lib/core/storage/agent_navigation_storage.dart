import 'package:shared_preferences/shared_preferences.dart';

class AgentNavigationStorage {
  AgentNavigationStorage._();

  static const _lastTabIndexKey = 'agent.lastTabIndex';

  static Future<int> getLastTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastTabIndexKey) ?? 0;
  }

  static Future<void> saveLastTabIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTabIndexKey, index);
  }

  static Future<void> clearLastTabIndex() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastTabIndexKey);
  }
}
