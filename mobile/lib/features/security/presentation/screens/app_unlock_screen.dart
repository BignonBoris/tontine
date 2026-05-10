import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';

class AppUnlockScreen extends StatefulWidget {
  final bool replaceStack;

  const AppUnlockScreen({super.key, this.replaceStack = true});

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(30, compact ? 16 : 24, 30, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      SizedBox(height: compact ? 16 : 20),
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
                            'Verrouillage',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 16 : 20),
                      Text(
                        "Deverrouiller l'application",
                        style: GoogleFonts.poppins(
                          fontSize: compact ? 24 : 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Entrez votre code PIN pour acceder a votre espace.',
                        style: GoogleFonts.inter(
                          fontSize: compact ? 14 : 15,
                          color: Colors.white.withValues(alpha: 0.78),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: compact ? 24 : 30),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          18,
                          compact ? 16 : 18,
                          18,
                          compact ? 16 : 18,
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
                            Text(
                              'Code de securite',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              onChanged: (_) {
                                if (_error != null) {
                                  setState(() => _error = null);
                                }
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Code PIN',
                                hintText: '4 chiffres',
                                errorText: _error,
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 18 : 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _unlock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
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
                                  'Deverrouiller',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
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

  Future<void> _unlock() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final isValid = await LocalSecurityService.verifyPin(
      _pinController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (!isValid) {
      setState(() {
        _isSubmitting = false;
        _error = 'PIN incorrect';
      });
      return;
    }

    if (widget.replaceStack) {
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
      return;
    }

    Navigator.pop(context, true);
  }
}
