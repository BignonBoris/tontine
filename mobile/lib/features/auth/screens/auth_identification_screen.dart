import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/features/auth/data/services/local_auth_service.dart';
import 'package:mobile/features/auth/data/services/biometric_service.dart';
import 'package:mobile/features/auth/widgets/auth_help_bottom_sheet.dart';
import 'package:mobile/features/auth/widgets/legal_terms_bottom_sheet.dart';

class AuthIdentificationScreen extends StatefulWidget {
  final bool isRegistration;

  const AuthIdentificationScreen({super.key, required this.isRegistration});

  @override
  State<AuthIdentificationScreen> createState() =>
      _AuthIdentificationScreenState();
}

class _AuthIdentificationScreenState extends State<AuthIdentificationScreen> {
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  late bool _isRegistrationMode;
  bool _isValid = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _normalizedPhone = '';
  
  bool _canUseBiometrics = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _isRegistrationMode = widget.isRegistration;
    _checkBiometrics();
    _loadSuggestedPhoneNumber();
  }

  Future<void> _checkBiometrics() async {
    final canUse = await BiometricService.isBiometricAvailable();
    final isEnabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _canUseBiometrics = canUse;
        _isBiometricEnabled = isEnabled;
      });
    }
  }

  Future<void> _triggerBiometricAuth() async {
    if (!_canUseBiometrics || !_isBiometricEnabled) return;
    final savedPin = await BiometricService.getSavedPin();
    if (savedPin == null || savedPin.isEmpty) return;

    final authenticated = await BiometricService.authenticate();
    if (authenticated && mounted) {
      setState(() {
        _pinController.text = savedPin;
        _refreshValidation();
      });
      // Automatically submit if everything is valid
      if (_isValid) {
        _handleContinue(context);
      }
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestedPhoneNumber() async {
    final suggestedPhone = await LocalAuthService.loadSuggestedPhoneNumber();
    if (!mounted || suggestedPhone == null || suggestedPhone.isEmpty) {
      return;
    }

    setState(() {
      _phoneController.text = suggestedPhone;
      _normalizedPhone = LocalAuthService.normalizePhone(suggestedPhone);
      _refreshValidation();
    });
    
    if (!_isRegistrationMode) {
      _triggerBiometricAuth();
    }
  }

  void _refreshValidation() {
    final registrationIdentityOk =
        !_isRegistrationMode ||
        (AppInputRules.isValidPersonName(_lastNameController.text) &&
            AppInputRules.isValidPersonName(_firstNameController.text));
    final phoneOk = AppInputRules.isValidPhone(_normalizedPhone);
    final pinValue = _pinController.text.trim();
    final pinOk =
        _isRegistrationMode || AppInputRules.isValidPin(pinValue);
    _isValid = registrationIdentityOk && phoneOk && pinOk;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(30),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                AppTheme.accentColor.withValues(alpha: 0.18),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentDarkColor.withValues(
                                  alpha: 0.14,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Image.asset(AppTheme.brandIconAsset),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _isRegistrationMode
                            ? 'Ouverture de compte'
                            : 'Accéder à mon compte',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isRegistrationMode
                            ? 'Renseignez vos informations personnelles pour démarrer votre épargne.'
                            : 'Entrez votre numéro de téléphone et votre code PIN pour accéder à votre espace.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isRegistrationMode) ...[
                              _buildTextInputCard(
                                controller: _lastNameController,
                                hintText: 'Nom',
                                icon: Icons.person_outline_rounded,
                                isValid: AppInputRules.isValidPersonName(_lastNameController.text),
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.familyName],
                                inputFormatters: AppInputRules.personNameFormatters,
                                onChanged: (_) {
                                  setState(() {
                                    _errorMessage = null;
                                    _refreshValidation();
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextInputCard(
                                controller: _firstNameController,
                                hintText: 'Prénom',
                                icon: Icons.badge_outlined,
                                isValid: AppInputRules.isValidPersonName(_firstNameController.text),
                                textCapitalization: TextCapitalization.words,
                                autofillHints: const [AutofillHints.givenName],
                                inputFormatters: AppInputRules.personNameFormatters,
                                onChanged: (_) {
                                  setState(() {
                                    _errorMessage = null;
                                    _refreshValidation();
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppInputRules.isValidPhone(_normalizedPhone)
                                      ? AppTheme.secondaryColor.withValues(alpha: 0.60)
                                      : AppTheme.accentColor.withValues(alpha: 0.30),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentDarkColor.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.zero,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: IntlPhoneField(
                                      controller: _phoneController,
                                      initialCountryCode: 'BJ',
                                      disableLengthCheck: true,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: _isRegistrationMode
                                          ? TextInputAction.done
                                          : TextInputAction.next,
                                      autovalidateMode: AutovalidateMode.disabled,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15.5,
                                        letterSpacing: 1.1,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.textPrimaryColor,
                                      ),
                                      dropdownTextStyle: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryColor,
                                      ),
                                      flagsButtonPadding: const EdgeInsets.only(
                                        left: 12,
                                        right: 4,
                                      ),
                                      showCountryFlag: true,
                                      showDropdownIcon: false,
                                      decoration: InputDecoration(
                                        hintText: 'Numéro de téléphone',
                                        hintStyle: GoogleFonts.poppins(
                                          color: AppTheme.textSecondaryColor,
                                          fontSize: 14,
                                          letterSpacing: 0,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        counterText: '',
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 0,
                                          vertical: 14,
                                        ),
                                      ),
                                      invalidNumberMessage: 'Numéro invalide',
                                      onChanged: (phone) {
                                        var cleanNumber = phone.number.trim();
                                        final cleanDial = phone.countryCode
                                            .replaceAll('+', '')
                                            .trim();
                                        if (cleanNumber.startsWith('+$cleanDial')) {
                                          cleanNumber = cleanNumber.substring(
                                            cleanDial.length + 1,
                                          );
                                        } else if (cleanNumber.startsWith(cleanDial) &&
                                            cleanNumber.length > 8) {
                                          cleanNumber = cleanNumber.substring(
                                            cleanDial.length,
                                          );
                                        } else if (cleanNumber.startsWith('+')) {
                                          cleanNumber = cleanNumber.substring(1);
                                        }

                                        if (cleanNumber != phone.number) {
                                          _phoneController.value =
                                              TextEditingValue(
                                            text: cleanNumber,
                                            selection: TextSelection.collapsed(
                                              offset: cleanNumber.length,
                                            ),
                                          );
                                        }

                                        final dialCode =
                                            phone.countryCode.startsWith('+')
                                                ? phone.countryCode
                                                : '+${phone.countryCode}';
                                        final rawDigits = cleanNumber.replaceAll(
                                          RegExp(r'\D'),
                                          '',
                                        );
                                        final fullPhone = '$dialCode$rawDigits';
                                        final normalizedPhone =
                                            LocalAuthService.normalizePhone(
                                              fullPhone,
                                            );
                                        setState(() {
                                          _errorMessage = null;
                                          _normalizedPhone = normalizedPhone;
                                          _refreshValidation();
                                        });
                                      },
                                      onCountryChanged: (_) {
                                        setState(() {
                                          _errorMessage = null;
                                        });
                                      },
                                    ),
                                  ),
                                  if (AppInputRules.isValidPhone(_normalizedPhone))
                                    const Padding(
                                      padding: EdgeInsets.only(right: 12),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        color: AppTheme.secondaryColor,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isRegistrationMode) ...[
                        const SizedBox(height: 16),
                        _buildTextInputCard(
                          controller: _pinController,
                          hintText: 'Code PIN (4 chiffres)',
                          icon: Icons.lock_outline_rounded,
                          isValid: AppInputRules.isValidPin(_pinController.text),
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          enableInteractiveSelection: false,
                          enableSuggestions: false,
                          autocorrect: false,
                          inputFormatters: AppInputRules.pinFormatters,
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                              _refreshValidation();
                            });
                          },
                          customSuffixIcon: (_canUseBiometrics && _isBiometricEnabled) ? IconButton(
                            icon: const Icon(Icons.fingerprint_rounded, color: AppTheme.primaryColor),
                            onPressed: _triggerBiometricAuth,
                          ) : null,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _handleForgotPassword,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Code PIN oublié ?',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFB91C1C),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFB91C1C),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFFB91C1C),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 28, bottom: 12),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: _isValid && !_isSubmitting
                                ? AppTheme.accentGradient
                                : null,
                            color: _isValid && !_isSubmitting
                                ? null
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: _isValid && !_isSubmitting
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accentColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _isValid && !_isSubmitting
                                  ? () => _handleContinue(context)
                                  : null,
                              child: Center(
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Continuer',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white.withValues(
                                                alpha: _isValid ? 1.0 : 0.50,
                                              ),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 18,
                                            color: Colors.white.withValues(
                                              alpha: _isValid ? 1.0 : 0.50,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                        if (_isRegistrationMode) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.70),
                                  height: 1.35,
                                ),
                                children: [
                                  const TextSpan(
                                    text: "En continuant, vous acceptez nos ",
                                  ),
                                  TextSpan(
                                    text: "CGU",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            LegalTermsBottomSheet.show(
                                              context,
                                              initialTab: 0,
                                            );
                                          },
                                  ),
                                  const TextSpan(text: " et notre "),
                                  TextSpan(
                                    text: "Politique de Confidentialité",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap = () {
                                            LegalTermsBottomSheet.show(
                                              context,
                                              initialTab: 1,
                                            );
                                          },
                                  ),
                                  const TextSpan(text: "."),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "Code de sécurité transmis par WhatsApp",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegistrationMode = !_isRegistrationMode;
                              _errorMessage = null;
                              _refreshValidation();
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegistrationMode
                                      ? "Vous avez déjà un compte ? "
                                      : "Pas encore de compte ? ",
                                ),
                                TextSpan(
                                  text: _isRegistrationMode
                                      ? "Se connecter"
                                      : "Ouvrir un compte",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton.icon(
                          onPressed: () => AuthHelpBottomSheet.show(context),
                          icon: Icon(
                            Icons.help_outline_rounded,
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          label: Text(
                            "Besoin d'aide ?",
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.60),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Conforme aux normes de sécurité financière BCEAO',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleForgotPassword() {
    FocusScope.of(context).unfocus();
    AuthHelpBottomSheet.show(context);
  }

  Future<void> _handleContinue(BuildContext context) async {
    FocusScope.of(context).unfocus();
    TextInput.finishAutofillContext();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await LocalAuthService.requestOtp(
      rawPhoneNumber: _normalizedPhone,
      isRegistration: _isRegistrationMode,
      pinCode: _isRegistrationMode || _pinController.text.trim().isEmpty
          ? null
          : _pinController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!result.isSuccess) {
      setState(() {
        _errorMessage = result.message;
      });
      return;
    }

    if (!context.mounted) {
      return;
    }

    final formattedFirstName = _isRegistrationMode
        ? AppInputRules.capitalizePersonName(_firstNameController.text)
        : null;
    final formattedLastName = _isRegistrationMode
        ? AppInputRules.capitalizePersonName(_lastNameController.text)
        : null;

    Navigator.pushNamed(
      context,
      '/auth_otp',
      arguments: {
        'phoneNumber': result.phoneNumber,
        'normalizedPhoneNumber': _normalizedPhone,
        'isRegistration': _isRegistrationMode,
        'pinCode': _isRegistrationMode || _pinController.text.trim().isEmpty
            ? null
            : _pinController.text.trim(),
        'firstName': formattedFirstName,
        'lastName': formattedLastName,
      },
    );
  }

  Widget _buildTextInputCard({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required ValueChanged<String> onChanged,
    bool isValid = false,
    TextInputType? keyboardType,
    bool obscureText = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Iterable<String>? autofillHints,
    bool enableInteractiveSelection = true,
    bool enableSuggestions = true,
    bool autocorrect = true,
    Widget? customSuffixIcon,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValid
              ? AppTheme.secondaryColor.withValues(alpha: 0.60)
              : AppTheme.accentColor.withValues(alpha: 0.30),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentDarkColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.next,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autofillHints: autofillHints,
        obscureText: obscureText,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        enableInteractiveSelection: enableInteractiveSelection,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 36),
          suffixIcon: customSuffixIcon ?? (isValid
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.secondaryColor,
                  size: 20,
                )
              : null),
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: AppTheme.textSecondaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

}
