/// Utility class for masking sensitive data displayed in the UI.
///
/// Provides methods to partially hide phone numbers and financial balances
/// to protect against "shoulder surfing" (someone reading data over the agent's shoulder).
class MaskUtils {
  MaskUtils._();

  /// Masks a phone number, keeping only the country code prefix and last 2 digits visible.
  ///
  /// Examples:
  ///   "+229 97 12 34 56"  -> "+229 97 *** ** 56"
  ///   "97123456"          -> "97 *** ** 56"
  ///   "22997123456"       -> "+229 97 *** ** 56"
  static String maskPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;

    // Remove spaces for processing
    final clean = phone.replaceAll(RegExp(r'\s'), '');

    // If 10 digits (no country code), e.g. 9712345678
    if (RegExp(r'^\d{8,}$').hasMatch(clean)) {
      final visible = clean.substring(0, 2); // first 2 digits
      final last2 = clean.length >= 2 ? clean.substring(clean.length - 2) : clean;
      return '$visible *** ** $last2';
    }

    // If starts with + or contains country code, e.g. +22997123456
    if (clean.startsWith('+')) {
      // Extract country code (up to 4 chars, then the rest)
      final withoutPlus = clean.substring(1);
      // Try to guess country code length (3 digits for ECOWAS)
      if (withoutPlus.length > 5) {
        final countryCode = '+${withoutPlus.substring(0, 3)}';
        final national = withoutPlus.substring(3);
        final visibleNational = national.length >= 2 ? national.substring(0, 2) : national;
        final last2 = national.length >= 2 ? national.substring(national.length - 2) : national;
        return '$countryCode $visibleNational *** ** $last2';
      }
    }

    // Fallback: mask middle part
    if (clean.length <= 4) return clean;
    final first2 = clean.substring(0, 2);
    final last2 = clean.substring(clean.length - 2);
    return '$first2 *** ** $last2';
  }

  /// Masks a financial balance/amount, showing only asterisks.
  ///
  /// Examples:
  ///   "150 000 F CFA"  -> "*** *** F CFA"
  ///   "1 500 F"        -> "*** *** F"
  static String maskBalance(String formattedAmount) {
    if (formattedAmount.isEmpty) return formattedAmount;

    // Detect currency suffix (F CFA, FCFA, F, XOF, etc.)
    final patterns = ['F CFA', 'FCFA', ' F', 'XOF'];
    for (final suffix in patterns) {
      if (formattedAmount.endsWith(suffix)) {
        return '*** ***$suffix';
      }
    }

    return '*** ***';
  }
}
