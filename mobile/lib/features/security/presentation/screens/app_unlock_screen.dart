import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/features/auth/data/services/biometric_service.dart';

class AppUnlockScreen extends StatefulWidget {
  final bool replaceStack;

  const AppUnlockScreen({super.key, this.replaceStack = true});

  @override
  State<AppUnlockScreen> createState() => _AppUnlockScreenState();
}

class _AppUnlockScreenState extends State<AppUnlockScreen>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isChecking = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _isError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Animation de secousse pour code faux
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isBiometricAvailable();
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }

    if (enabled) {
      _triggerBiometric();
    }
  }

  Future<void> _triggerBiometric() async {
    final success = await BiometricService.authenticate();
    if (success) {
      _onUnlockSuccess();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPress(String value) {
    if (_isChecking || _pin.length >= 4) return;
    setState(() {
      _isError = false;
      _pin += value;
    });
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onCancel() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isChecking = true;
    });

    final isValid = await LocalSecurityService.verifyPin(_pin);
    if (!mounted) return;

    if (isValid) {
      _onUnlockSuccess();
    } else {
      setState(() {
        _isError = true;
        _pin = '';
        _isChecking = false;
      });
      _shakeController.forward(from: 0);
    }
  }

  void _onUnlockSuccess() {
    if (widget.replaceStack) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/dashboard', (route) => false);
    } else {
      Navigator.pop(context, true);
    }
  }

  Widget _buildDot(int index) {
    final isFilled = index < _pin.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isError
            ? Colors.redAccent
            : (isFilled ? Colors.white : Colors.white.withOpacity(0.2)),
      ),
    );
  }

  Widget _buildKeypadButton(String text, {VoidCallback? onTap, Widget? icon}) {
    final isText = icon == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => _onKeyPress(text),
        customBorder: const CircleBorder(),
        splashColor: Colors.white.withOpacity(0.2),
        highlightColor: Colors.white.withOpacity(0.1),
        child: Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: text.isEmpty && icon == null
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Center(
            child: icon ??
                Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onCancel,
        customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40)),
        splashColor: Colors.white.withOpacity(0.2),
        child: Container(
          width: 75,
          height: 75,
          alignment: Alignment.center,
          child: Text(
            'Annuler',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fond dégradé bleu nuit inspiré du design
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF071936),
        const Color(0xFF030B18),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(gradient: bgGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                
                // Icône Cadenas
                const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                
                // Titre
                Text(
                  'Application Verrouillée',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Sous-titre
                Text(
                  'Veuillez saisir votre code PIN',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                
                const Spacer(flex: 1),
                
                // Indicateurs du code PIN avec secousse
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) => _buildDot(index)),
                      ),
                    );
                  },
                ),
                
                const Spacer(flex: 1),
                
                // Clavier numérique
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeypadButton('1'),
                          _buildKeypadButton('2'),
                          _buildKeypadButton('3'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeypadButton('4'),
                          _buildKeypadButton('5'),
                          _buildKeypadButton('6'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildKeypadButton('7'),
                          _buildKeypadButton('8'),
                          _buildKeypadButton('9'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCancelButton(),
                          _buildKeypadButton('0'),
                          if (_biometricAvailable && _biometricEnabled)
                            _buildKeypadButton(
                              '',
                              onTap: _triggerBiometric,
                              icon: const Icon(
                                Icons.face_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            )
                          else
                            const SizedBox(width: 75, height: 75), // Spacer
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
