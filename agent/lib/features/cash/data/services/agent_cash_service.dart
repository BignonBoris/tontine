import 'package:shared_preferences/shared_preferences.dart';

class AgentCashService {
  static const String _cashFloatKey = 'current_cash_float';
  static const String _maxFloatLimitKey = 'max_cash_float_limit';
  static const double _defaultMaxFloat = 500000.0;

  Future<double> getCurrentFloat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_cashFloatKey) ?? 0.0;
  }

  Future<double> getMaxFloatLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_maxFloatLimitKey) ?? _defaultMaxFloat;
  }

  Future<bool> canAcceptPayment(double amount) async {
    final currentFloat = await getCurrentFloat();
    final maxFloat = await getMaxFloatLimit();
    return (currentFloat + amount) <= maxFloat;
  }

  Future<void> addCash(double amount) async {
    if (!await canAcceptPayment(amount)) {
      throw Exception('Plafond de caisse dépassé. Veuillez faire un reversement.');
    }
    final prefs = await SharedPreferences.getInstance();
    final currentFloat = await getCurrentFloat();
    await prefs.setDouble(_cashFloatKey, currentFloat + amount);
  }
  
  Future<void> resetFloat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cashFloatKey, 0.0);
  }
}
