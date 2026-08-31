import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/features/auth/data/services/local_auth_service.dart';
import 'package:mobile/features/auth/widgets/auth_help_bottom_sheet.dart';

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

  String _phoneNumber = '+229 XX XX XX XX XX';
  String _normalizedPhoneNumber = '';
  bool _isRegistration = false;
  String? _pinCode;
  String? _firstName;
  String? _lastName;
  String? _birthDate;
  bool _argumentsLoaded = false;
  bool _isSubmitting = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  int _secondsRemaining = 120;
  DateTime? _timerEndTime;
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
      if (args['isRegistration'] is bool) {
        _isRegistration = args['isRegistration'] as bool;
      }
      if (args['pinCode'] is String) {
        _pinCode = args['pinCode'] as String;
      }
      if (args['firstName'] is String) {
        _firstName = args['firstName'] as String;
      }
      if (args['lastName'] is String) {
        _lastName = args['lastName'] as String;
      }
      if (args['birthDate'] is String) {
        _birthDate = args['birthDate'] as String;
      }
    }
    _argumentsLoaded = true;
    _startTimer(120);
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
              padding: EdgeInsets.fromLTRB(28, compact ? 8 : 16, 28, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
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
                          'Vérification du numéro',
                          style: GoogleFonts.poppins(
                            fontSize: compact ? 24 : 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Saisissez le code de sécurité à 4 chiffres envoyé sur votre compte WhatsApp.',
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
                                alpha: 0.38,
                              ),
                              width: 1.2,
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
                              Text(
                                'Code envoyé au',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                LocalAuthService.formatPhoneForInput(_phoneNumber),
                                style: GoogleFonts.poppins(
                                  fontSize: compact ? 15.5 : 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                              SizedBox(height: compact ? 18 : 24),
                              Center(
                                child: AutofillGroup(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: compact ? 10 : 12,
                                    runSpacing: compact ? 10 : 12,
                                    children: List.generate(
                                      4,
                                      (index) => _buildOtpBox(
                                        index,
                                        AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
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
                                        'Ne partagez jamais ce code, même avec un agent VizioBox.',
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
                                _InlineAuthMessage(
                                  message: _feedbackMessage!,
                                  isError: _feedbackIsError,
                                  onClose: () {
                                    setState(() {
                                      _feedbackMessage = null;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        Center(
                          child: Builder(
                            builder: (context) {
                              final minutes = (_secondsRemaining ~/ 60)
                                  .toString()
                                  .padLeft(2, '0');
                              final seconds = (_secondsRemaining % 60)
                                  .toString()
                                  .padLeft(2, '0');

                              return TextButton.icon(
                                onPressed: _secondsRemaining == 0 && !_isSubmitting
                                    ? _handleResendCode
                                    : null,
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: _secondsRemaining == 0
                                      ? AppTheme.accentColor
                                      : Colors.white.withValues(alpha: 0.4),
                                ),
                                label: Text(
                                  _secondsRemaining == 0
                                      ? 'Renvoyer le code'
                                      : 'Renvoyer le code ($minutes:$seconds)',
                                  style: GoogleFonts.inter(
                                    color: _secondsRemaining == 0
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              );
                            },
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
                              gradient: canSubmit && !_isSubmitting
                                  ? AppTheme.accentGradient
                                  : null,
                              color: canSubmit && !_isSubmitting
                                  ? null
                                  : Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: canSubmit && !_isSubmitting
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
                              onPressed: canSubmit && !_isSubmitting
                                  ? _handleVerification
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
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Vérifier et continuer',
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, Color primaryColor) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[index].text.isEmpty &&
            index > 0) {
          _focusNodes[index - 1].requestFocus();
          _controllers[index - 1].clear();
          HapticFeedback.selectionClick();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: 60,
        height: 64,
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofillHints: const [AutofillHints.oneTimeCode],
          enableSuggestions: false,
          autocorrect: false,
          onChanged: (value) {
            setState(() {
              _feedbackMessage = null;
            });

            // Support du Coller Rapide (Paste de 4 chiffres ex: "4829")
            final cleanDigits = value.replaceAll(RegExp(r'\D'), '');
            if (cleanDigits.length == 4) {
              for (int i = 0; i < 4; i++) {
                _controllers[i].text = cleanDigits[i];
              }
              _focusNodes.last.unfocus();
              HapticFeedback.mediumImpact();
              if (!_isSubmitting) {
                _handleVerification();
              }
              return;
            }

            if (value.length > 1) {
              _controllers[index].text = value.substring(value.length - 1);
              _controllers[index].selection = TextSelection.fromPosition(
                TextPosition(offset: _controllers[index].text.length),
              );
            }

            if (value.isNotEmpty) {
              HapticFeedback.selectionClick();
              if (index < _focusNodes.length - 1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _focusNodes[index + 1].requestFocus();
                  }
                });
              }
            }

            if (value.isEmpty && index > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _focusNodes[index - 1].requestFocus();
                }
              });
            }

            // Soumission automatique si les 4 cases sont remplies
            if (_controllers.every((c) => c.text.isNotEmpty) && !_isSubmitting) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_isSubmitting) {
                  _handleVerification();
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
            ...AppInputRules.otpFormatters,
          ],
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: _controllers[index].text.isNotEmpty
                ? const Color(0xFFF6F9FD)
                : const Color(0xFFFBFCFE),
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _controllers[index].text.isNotEmpty
                    ? AppTheme.accentColor.withValues(alpha: 0.65)
                    : AppTheme.primaryColor.withValues(alpha: 0.25),
                width: _controllers[index].text.isNotEmpty ? 1.5 : 1.3,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleVerification() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
    });

    final code = _controllers.map((controller) => controller.text).join();
    final result = await LocalAuthService.verifyOtp(
      rawPhoneNumber: _normalizedPhoneNumber,
      otpCode: code,
      pinCode: _pinCode,
      firstName: _isRegistration ? _firstName : null,
      lastName: _isRegistration ? _lastName : null,
      birthDate: _isRegistration ? _birthDate : null,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!result.isSuccess) {
      HapticFeedback.vibrate();
      setState(() {
        _feedbackMessage = result.message;
        _feedbackIsError = true;
        for (final controller in _controllers) {
          controller.clear();
        }
      });
      _focusNodes.first.requestFocus();
      return;
    }

    HapticFeedback.mediumImpact();

    if (!_isRegistration) {
      if (_pinCode != null && _pinCode!.trim().length == 4) {
        await LocalSecurityService.saveSettings(
          pinEnabled: true,
          biometricEnabled: false,
          pinCode: _pinCode!.trim(),
          phoneNumber: _normalizedPhoneNumber,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
      return;
    }

    final appLockEnabled = await LocalSecurityService.hasAppLockEnabled();
    if (!mounted) {
      return;
    }

    if (appLockEnabled) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
      return;
    }

    if (_pinCode != null && _pinCode!.trim().length == 4) {
      await LocalSecurityService.saveSettings(
        pinEnabled: true,
        biometricEnabled: false,
        pinCode: _pinCode!.trim(),
        phoneNumber: _normalizedPhoneNumber,
      );
    }

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/auth_pin_setup',
      (route) => false,
    );
  }

  Future<void> _handleResendCode() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _feedbackMessage = null;
      _isSubmitting = true;
    });

    final result = await LocalAuthService.resendOtp(
      rawPhoneNumber: _normalizedPhoneNumber,
      isRegistration: _isRegistration,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!result.isSuccess) {
      HapticFeedback.vibrate();
      setState(() {
        _feedbackMessage = result.message;
        _feedbackIsError = true;
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _feedbackMessage = 'Un nouveau code a été envoyé sur WhatsApp.';
      _feedbackIsError = false;
      for (final controller in _controllers) {
        controller.clear();
      }
    });
    _focusNodes.first.requestFocus();
    _startTimer(120);
  }

  void _startTimer([int seconds = 120]) {
    _timer?.cancel();
    _secondsRemaining = seconds;
    _timerEndTime = DateTime.now().add(Duration(seconds: seconds));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _timerEndTime != null
          ? _timerEndTime!.difference(DateTime.now()).inSeconds
          : _secondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _secondsRemaining = remaining;
      });
    });
  }
}

class _InlineAuthMessage extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback onClose;

  const _InlineAuthMessage({
    required this.message,
    required this.isError,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isError
        ? const Color(0xFFFFF1F2)
        : const Color(0xFFECFDF5);
    final borderColor = isError
        ? const Color(0xFFFECACA)
        : const Color(0xFFA7F3D0);
    final foregroundColor = isError
        ? const Color(0xFFB91C1C)
        : const Color(0xFF047857);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: foregroundColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                color: foregroundColor,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

