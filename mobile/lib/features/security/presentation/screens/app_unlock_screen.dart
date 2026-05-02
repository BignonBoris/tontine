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
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: AppTheme.primaryColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Deverrouiller l'application",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez votre code PIN pour acceder a votre espace.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Code PIN',
                    errorText: _error,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _unlock,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Deverrouiller'),
                  ),
                ),
              ],
            ),
          ),
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
