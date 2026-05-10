import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/data/services/local_auth_service.dart';

class AuthOtpScreen extends StatefulWidget {
  const AuthOtpScreen({super.key});

  @override
  State<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends State<AuthOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  String _phoneNumber = '+229 XX XX XX 00';
  String _normalizedPhoneNumber = '';
  String _demoOtpCode = '0000';
  bool _isRegistration = false;
  bool _argumentsLoaded = false;
  bool _isSubmitting = false;
  int _secondsRemaining = 59;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsLoaded) {
      return;
    }

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<dynamic, dynamic>?;
    if (args != null) {
      if (args['phoneNumber'] is String) {
        _phoneNumber = args['phoneNumber'] as String;
      }
      if (args['normalizedPhoneNumber'] is String) {
        _normalizedPhoneNumber = args['normalizedPhoneNumber'] as String;
      }
      if (args['demoOtpCode'] is String) {
        _demoOtpCode = args['demoOtpCode'] as String;
      }
      if (args['isRegistration'] is bool) {
        _isRegistration = args['isRegistration'] as bool;
      }
    }
    _argumentsLoaded = true;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _controllers.every(
      (controller) => controller.text.isNotEmpty,
    );

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
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(30, compact ? 12 : 20, 30, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: compact ? 82 : 96,
                          height: compact ? 82 : 96,
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
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentDarkColor.withValues(alpha: 0.14),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Image.asset(AppTheme.brandIconAsset),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            _isRegistration ? 'Inscription' : 'Connexion',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 18),
                      Text(
                        'Verification',
                        style: GoogleFonts.poppins(
                          fontSize: compact ? 24 : 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Saisissez le code a 4 chiffres envoye au numero ci-dessous.',
                        style: GoogleFonts.inter(
                          fontSize: compact ? 14 : 15,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: compact ? 20 : 26),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Numero verifie',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _phoneNumber,
                              style: GoogleFonts.poppins(
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            SizedBox(height: compact ? 14 : 18),
                            _OtpDemoBanner(code: _demoOtpCode),
                            SizedBox(height: compact ? 16 : 22),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: compact ? 10 : 12,
                                runSpacing: compact ? 10 : 12,
                                children: List.generate(
                                  4,
                                  (index) =>
                                      _buildOtpBox(index, AppTheme.accentColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 14 : 20),
                      Center(
                        child: TextButton(
                          onPressed: _secondsRemaining == 0 && !_isSubmitting
                              ? _handleResendCode
                              : null,
                          child: Text(
                            _secondsRemaining == 0
                                ? 'Renvoyer le code'
                                : 'Renvoyer le code (00:${_secondsRemaining.toString().padLeft(2, '0')})',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: compact ? 16 : 22, bottom: 6),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canSubmit && !_isSubmitting
                                ? _handleVerification
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              disabledBackgroundColor: Colors.grey.shade300,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                    'Verifier et continuer',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, Color primaryColor) {
    return SizedBox(
      width: 60,
      height: 64,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) {
          setState(() {});
          if (value.length == 1 && index < _focusNodes.length - 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _focusNodes[index + 1].requestFocus();
              }
            });
          }
          if (value.isEmpty && index > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _focusNodes[index - 1].requestFocus();
              }
            });
          }
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        textInputAction: index == _focusNodes.length - 1
            ? TextInputAction.done
            : TextInputAction.next,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFFBFCFE),
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Future<void> _handleVerification() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    final code = _controllers.map((controller) => controller.text).join();
    final result = await LocalAuthService.verifyOtp(
      rawPhoneNumber: _normalizedPhoneNumber,
      otpCode: code,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    final appLockEnabled = await LocalSecurityService.hasAppLockEnabled();
    if (!mounted) {
      return;
    }

    if (_isRegistration) {
      if (appLockEnabled) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/auth_pin_setup',
        (route) => false,
      );
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      appLockEnabled ? '/unlock' : '/dashboard',
      (route) => false,
    );
  }

  Future<void> _handleResendCode() async {
    final result = await LocalAuthService.resendOtp(
      rawPhoneNumber: _normalizedPhoneNumber,
      isRegistration: _isRegistration,
    );
    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    setState(() {
      _demoOtpCode = result.otpCode ?? _demoOtpCode;
      _secondsRemaining = 59;
      for (final controller in _controllers) {
        controller.clear();
      }
    });
    _focusNodes.first.requestFocus();
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Un nouveau code a ete genere.")),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }
}

class _OtpDemoBanner extends StatelessWidget {
  final String code;

  const _OtpDemoBanner({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sms_outlined, color: AppTheme.accentDarkColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Code de test MVP : $code",
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentDarkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
