import 'package:flutter/services.dart';

class AgentInputRules {
  AgentInputRules._();

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

  static final List<TextInputFormatter> confirmationCodeFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(6),
  ];

  static final List<TextInputFormatter> personNameFormatters = [
    FilteringTextInputFormatter.allow(
      RegExp(r"[A-Za-z\u00C0-\u024F' -]"),
    ),
    LengthLimitingTextInputFormatter(80),
  ];

  static final List<TextInputFormatter> withdrawalReferenceFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
    LengthLimitingTextInputFormatter(40),
    _UpperCaseTextFormatter(),
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

  static String normalizeReference(String rawReference) {
    return rawReference.trim().toUpperCase();
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

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
