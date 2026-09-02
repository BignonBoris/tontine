import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/features/auth/data/services/local_auth_service.dart';
import 'package:mobile/features/auth/widgets/auth_help_bottom_sheet.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';
import 'package:mobile/features/dashboard/domain/entities/profile_preferences.dart';

class AuthPinSetupScreen extends StatefulWidget {
  const AuthPinSetupScreen({super.key});

  @override
  State<AuthPinSetupScreen> createState() => _AuthPinSetupScreenState();
}

class _AuthPinSetupScreenState extends State<AuthPinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  String? _feedbackMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    return pin.length == 4 && confirm.length == 4 && pin == confirm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(28, compact ? 8 : 16, 28, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 20,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: compact ? 80 : 92,
                              height: compact ? 80 : 92,
                              padding: EdgeInsets.all(compact ? 12 : 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    AppTheme.accentColor.withValues(alpha: 0.18),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
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
                          SizedBox(height: compact ? 16 : 22),
                          Text(
                            'Définissez votre code PIN',
                            style: GoogleFonts.poppins(
                              fontSize: compact ? 24 : 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Ce code secret à 4 chiffres protégera l'accès à votre espace et sécurisera vos opérations.",
                            style: GoogleFonts.inter(
                              fontSize: compact ? 13.5 : 14.5,
                              color: Colors.white.withValues(alpha: 0.82),
                              height: 1.45,
                            ),
                          ),
                          SizedBox(height: compact ? 18 : 24),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              18,
                              compact ? 16 : 18,
                              18,
                              compact ? 16 : 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPinFieldCard(
                                  label: 'Nouveau code PIN',
                                  hintText: '4 chiffres secrets',
                                  controller: _pinController,
                                  obscure: _obscurePin,
                                  onToggleObscure: () {
                                    setState(() {
                                      _obscurePin = !_obscurePin;
                                    });
                                  },
                                  onChanged: (val) {
                                    if (val.length == 4) {
                                      HapticFeedback.selectionClick();
                                    }
                                    setState(() {
                                      _feedbackMessage = null;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().length != 4) {
                                      return 'Veuillez saisir un code PIN à 4 chiffres.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _buildPinFieldCard(
                                  label: 'Confirmer le code PIN',
                                  hintText: 'Retapez les 4 chiffres',
                                  controller: _confirmPinController,
                                  obscure: _obscureConfirmPin,
                                  onToggleObscure: () {
                                    setState(() {
                                      _obscureConfirmPin = !_obscureConfirmPin;
                                    });
                                  },
                                  onChanged: (val) {
                                    if (val.length == 4) {
                                      HapticFeedback.selectionClick();
                                    }
                                    setState(() {
                                      _feedbackMessage = null;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().length != 4) {
                                      return 'Veuillez confirmer votre code PIN.';
                                    }
                                    if (value.trim() != _pinController.text.trim()) {
                                      return 'Les deux codes PIN ne correspondent pas.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.shield_outlined,
                                        size: 16,
                                        color: AppTheme.primaryColor.withValues(alpha: 0.75),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Ne communiquez jamais ce code, même à un agent VizioBox.',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textSecondaryColor,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_feedbackMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFECACA),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFB91C1C),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _feedbackMessage!,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFB91C1C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: compact ? 14 : 18,
                          bottom: 6,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: _isValid && !_isSubmitting
                                    ? AppTheme.accentGradient
                                    : null,
                                color: _isValid && !_isSubmitting
                                    ? null
                                    : Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _isValid && !_isSubmitting
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.accentDarkColor
                                              .withValues(alpha: 0.30),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ElevatedButton(
                                onPressed: _isValid && !_isSubmitting
                                    ? _handleContinue
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
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
                                            'Activer mon code PIN',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
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
                              ],
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
                                  'Chiffrement local sécurisé & Conformité BCEAO',
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildPinFieldCard({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required ValueChanged<String> onChanged,
    required String? Function(String?) validator,
  }) {
    final isFieldValid = controller.text.trim().length == 4;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFieldValid
              ? AppTheme.secondaryColor.withValues(alpha: 0.60)
              : AppTheme.primaryColor.withValues(alpha: 0.12),
          width: isFieldValid ? 1.4 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            color: isFieldValid ? AppTheme.secondaryColor : AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              keyboardType: TextInputType.number,
              inputFormatters: [...AppInputRules.pinFormatters],
              maxLength: 4,
              onChanged: onChanged,
              validator: validator,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
                letterSpacing: obscure ? 4 : 1,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.70),
                ),
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor.withValues(alpha: 0.50),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppTheme.textSecondaryColor,
              size: 20,
            ),
            onPressed: onToggleObscure,
          ),
          if (isFieldValid) ...[
            const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.secondaryColor,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin != confirm) {
      HapticFeedback.vibrate();
      setState(() {
        _feedbackMessage = 'Les deux codes PIN ne sont pas identiques.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    HapticFeedback.mediumImpact();

    await LocalSecurityService.saveSettings(
      pinEnabled: true,
      biometricEnabled: false,
      pinCode: pin,
      phoneNumber: await LocalAuthService.loadSuggestedNormalizedPhoneNumber(),
    );

    unawaited(
      RemoteDashboardService(
        apiClient: ApiClient(invalidateSessionOnUnauthorized: false),
      )
          .savePreferences(
            ProfilePreferences.defaults().copyWith(
              pinEnabled: true,
              biometricEnabled: false,
              pinCode: pin,
            ),
          )
          .catchError((error) {
            debugPrint('Synchronisation distante du PIN échouée: $error');
          }),
    );

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/onboarding_goals',
      (route) => false,
    );
  }
}
