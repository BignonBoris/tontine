import 'package:intl/intl.dart';

String formatFCFA(num amount) {
  return NumberFormat('#,###', 'fr_FR').format(amount).replaceAll(',', ' ');
}
