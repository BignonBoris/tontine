import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/features/auth/data/services/local_auth_service.dart';

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
  bool _isValid = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _normalizedPhone = '';

  @override
  void initState() {
    super.initState();
    _loadSuggestedPhoneNumber();
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
  }

  void _refreshValidation() {
    final registrationIdentityOk =
        !widget.isRegistration ||
        (_lastNameController.text.trim().length >= 2 &&
            _firstNameController.text.trim().length >= 2);
    final phoneOk = _normalizedPhone.length == 10;
    final pinValue = _pinController.text.trim();
    final pinOk =
        widget.isRegistration || pinValue.isEmpty || pinValue.length == 4;
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
                        widget.isRegistration
                            ? 'Ouverture de compte'
                            : 'Acceder a mon compte',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Entrez vos informations pour continuer.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 34),
                      if (widget.isRegistration) ...[
                        _buildTextInputCard(
                          controller: _lastNameController,
                          hintText: 'Nom',
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                              _refreshValidation();
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildTextInputCard(
                          controller: _firstNameController,
                          hintText: 'Prenom',
                          onChanged: (_) {
                            setState(() {
                              _errorMessage = null;
                              _refreshValidation();
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.accentColor.withValues(alpha: 0.26),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentDarkColor.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: IntlPhoneField(
                          controller: _phoneController,
                          initialCountryCode: 'BJ',
                          disableLengthCheck: true,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.disabled,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimaryColor,
                          ),
                          dropdownTextStyle: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentDarkColor,
                          ),
                          flagsButtonPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          showCountryFlag: true,
                          showDropdownIcon: false,
                          decoration: InputDecoration(
                            hintText: 'Numero de telephone',
                            hintStyle: GoogleFonts.poppins(
                              color: AppTheme.textSecondaryColor,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 14,
                            ),
                          ),
                          invalidNumberMessage: 'Numero invalide',
                          onChanged: (phone) {
                            final normalizedPhone =
                                LocalAuthService.normalizePhone(phone.number);
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
                      if (!widget.isRegistration) ...[
                        const SizedBox(height: 18),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppTheme.accentColor.withValues(
                                alpha: 0.26,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentDarkColor.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: TextField(
                            controller: _pinController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            inputFormatters: AppInputRules.pinFormatters,
                            onChanged: (_) {
                              setState(() {
                                _errorMessage = null;
                                _refreshValidation();
                              });
                            },
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Code PIN (si disponible)',
                              hintStyle: GoogleFonts.poppins(
                                color: AppTheme.textSecondaryColor,
                                letterSpacing: 0,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              counterText: '',
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isValid && !_isSubmitting
                                ? () => _handleContinue(context)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              disabledBackgroundColor: Colors.grey.shade300,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Recevoir le code',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "Des frais de SMS peuvent s'appliquer",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
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

  Future<void> _handleContinue(BuildContext context) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await LocalAuthService.requestOtp(
      rawPhoneNumber: _normalizedPhone,
      isRegistration: widget.isRegistration,
      pinCode: widget.isRegistration || _pinController.text.trim().isEmpty
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

    Navigator.pushNamed(
      context,
      '/auth_otp',
      arguments: {
        'phoneNumber': result.phoneNumber,
        'normalizedPhoneNumber': _normalizedPhone,
        'isRegistration': widget.isRegistration,
        'demoOtpCode': result.otpCode,
        'pinCode': widget.isRegistration || _pinController.text.trim().isEmpty
            ? null
            : _pinController.text.trim(),
        'firstName': widget.isRegistration
            ? _firstNameController.text.trim()
            : null,
        'lastName': widget.isRegistration
            ? _lastNameController.text.trim()
            : null,
      },
    );
  }

  Widget _buildTextInputCard({
    required TextEditingController controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentDarkColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.next,
        onChanged: onChanged,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

}
