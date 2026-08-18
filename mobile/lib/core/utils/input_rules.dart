import 'package:flutter/services.dart';

class AppInputRules {
  AppInputRules._();

  static const int financialAmountStep = 100;

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
    LengthLimitingTextInputFormatter(4),
  ];

  static final List<TextInputFormatter> personNameFormatters = [
    FilteringTextInputFormatter.allow(
      RegExp(r"[A-Za-z\u00C0-\u024F' -]"),
    ),
    LengthLimitingTextInputFormatter(80),
  ];

  static String normalizePhone(String rawPhone) {
    final trimmed = rawPhone.trim();
    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits;
  }

  static String capitalizePersonName(String rawName) {
    final cleaned = normalizePersonName(rawName);
    if (cleaned.isEmpty) return '';
    return cleaned.split(' ').map((word) {
      if (word.isEmpty) return '';
      // Gérer les mots composés avec tiret (ex: Jean-Marc)
      if (word.contains('-')) {
        return word.split('-').map((part) {
          if (part.isEmpty) return '';
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        }).join('-');
      }
      // Gérer les noms avec apostrophe (ex: D'Almeida)
      if (word.contains("'") && word.length > 2 && word.indexOf("'") == 1) {
        final prefix = word[0].toUpperCase();
        final rest = word.substring(2);
        final restCapitalized = rest.isNotEmpty
            ? rest[0].toUpperCase() + rest.substring(1).toLowerCase()
            : '';
        return "$prefix'$restCapitalized";
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String normalizePersonName(String rawName) {
    return rawName
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r"^[-'\s]+|[-'\s]+$"), '')
        .trim();
  }

  static bool isValidPhone(String rawPhone) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');
    // Autorise les numéros régionaux et internationaux (8 à 15 chiffres utiles selon la norme E.164 ITU)
    if (digitsOnly.length < 8 || digitsOnly.length > 15) return false;
    // Anti-numéro factice répétitif (ex: 00000000, 1111111111)
    if (RegExp(r'^(\d)\1+$').hasMatch(digitsOnly)) return false;
    return true;
  }

  static bool isValidPin(String pin) {
    final trimmed = pin.trim();
    return trimmed.length == 4 && RegExp(r'^\d{4}$').hasMatch(trimmed);
  }

  static bool isWeakPin(String pin) {
    final trimmed = pin.trim();
    if (trimmed.length != 4) return true;
    const weakPins = [
      '0000',
      '1111',
      '2222',
      '3333',
      '4444',
      '5555',
      '6666',
      '7777',
      '8888',
      '9999',
      '1234',
      '4321',
      '0123',
      '3210',
    ];
    return weakPins.contains(trimmed);
  }

  static bool isValidPersonName(String rawName) {
    final normalized = normalizePersonName(rawName);
    return normalized.length >= 2 &&
        RegExp(r"^[A-Za-z\u00C0-\u024F]").hasMatch(normalized) &&
        !RegExp(r'\d').hasMatch(normalized);
  }
}
