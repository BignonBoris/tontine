import 'package:intl/intl.dart';

final NumberFormat _fcfaFormat = NumberFormat.currency(
  locale: 'fr_FR',
  symbol: 'F CFA',
  decimalDigits: 0,
);

String formatFcfa(num amount) => _fcfaFormat.format(amount);
