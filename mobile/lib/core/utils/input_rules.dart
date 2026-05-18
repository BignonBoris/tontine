import 'package:flutter/services.dart';

class AppInputRules {
  AppInputRules._();

  static final List<TextInputFormatter> phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static final List<TextInputFormatter> amountFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(12),
  ];

  static final List<TextInputFormatter> pinFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  static final List<TextInputFormatter> otpFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(1),
  ];

  static final List<TextInputFormatter> personNameFormatters = [
    FilteringTextInputFormatter.allow(
      RegExp(r"[A-Za-z\u00C0-\u024F' -]"),
    ),
    LengthLimitingTextInputFormatter(80),
  ];

  static String normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  static String normalizePersonName(String rawName) {
    return rawName
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r"^[-'\s]+|[-'\s]+$"), '')
        .trim();
  }

  static bool isValidPhone(String rawPhone) {
    return normalizePhone(rawPhone).length == 10;
  }

  static bool isValidPersonName(String rawName) {
    final normalized = normalizePersonName(rawName);
    return normalized.length >= 3 &&
        RegExp(r"^[A-Za-z\u00C0-\u024F]").hasMatch(normalized) &&
        !RegExp(r'\d').hasMatch(normalized);
  }
}
