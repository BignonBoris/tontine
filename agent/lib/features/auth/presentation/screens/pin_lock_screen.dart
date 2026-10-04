import 'dart:async';

import 'package:agent/core/security/biometric_service.dart';
import 'package:agent/core/security/pin_service.dart';
import 'package:agent/core/storage/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran de déverrouillage par PIN, affiché après auto-lock.
///
/// - Propose automatiquement la biométrie si disponible.
/// - Verrouille l'interface après 3 tentatives (30 s).
/// - Déclenche un logout forcé après 5 tentatives.
/// - Bouton "Changer de compte" pour retourner au login complet.
class PinLockScreen extends StatefulWidget {
  /// Appelé quand le PIN est validé avec succès.
  final VoidCallback onUnlocked;

  /// Appelé quand l'agent veut se déconnecter complètement.
  final VoidCallback onForceLogout;

  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    required this.onForceLogout,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;

  final List<String> _entered = [];
  String? _errorMessage;
  bool _isLocked = false;
  int _lockRemaining = 0;
  Timer? _lockTimer;
  bool _isBiometricAvailable = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
    _initLockStatus();
    _initBiometric();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  // ─── Init ──────────────────────────────────────────────────────────────────

  Future<void> _initLockStatus() async {
    final status = await PinService.getLockStatus();
    if (status.isLocked && mounted) {
      setState(() {
        _isLocked = true;
        _lockRemaining = status.remainingSeconds;
      });
      _startLockCountdown();
    }
  }

  Future<void> _initBiometric() async {
    final available = await BiometricService.isBiometricAvailable();
    if (mounted) {
      setState(() => _isBiometricAvailable = available);
      if (available) {
        // Légère pause pour que l'UI soit rendue avant la popup biométrique
        await Future<void>.delayed(const Duration(milliseconds: 300));
        _tryBiometric();
      }
    }
  }

  // ─── Biométrie ─────────────────────────────────────────────────────────────

  Future<void> _tryBiometric() async {
    final ok = await BiometricService.authenticate();
    if (ok && mounted) {
      widget.onUnlocked();
    }
  }

  // ─── Saisie PIN ────────────────────────────────────────────────────────────

  void _onDigit(String digit) {
    if (_isLocked || _entered.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered.add(digit);
      _errorMessage = null;
    });
    if (_entered.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_isLocked || _entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered.removeLast();
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    final pin = _entered.join();
    final result = await PinService.verifyPin(pin);

    switch (result.status) {
      case PinVerificationStatus.success:
        widget.onUnlocked();

      case PinVerificationStatus.wrongPin:
        _shakeController.forward(from: 0);
        HapticFeedback.heavyImpact();
        setState(() {
          _entered.clear();
          _errorMessage =
              'PIN incorrect. Il vous reste ${result.remainingAttempts} tentative(s).';
        });

      case PinVerificationStatus.locked:
        _shakeController.forward(from: 0);
        HapticFeedback.heavyImpact();
        setState(() {
          _entered.clear();
          _isLocked = true;
          _lockRemaining = result.remainingLockSeconds;
          _errorMessage = null;
        });
        _startLockCountdown();

      case PinVerificationStatus.forceLogout:
        HapticFeedback.heavyImpact();
        await SessionStorage.clear();
        widget.onForceLogout();

      case PinVerificationStatus.noPinSet:
        // Pas de PIN configuré → déverrouillage transparent
        widget.onUnlocked();
    }
  }

  void _startLockCountdown() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockRemaining--;
      });
      if (_lockRemaining <= 0) {
        timer.cancel();
        setState(() {
          _isLocked = false;
          _errorMessage = null;
        });
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildPinIndicator(),
                  const SizedBox(height: 16),
                  _buildStatusMessage(),
                  const Spacer(),
                  _buildKeypad(),
                  const SizedBox(height: 24),
                  _buildFooter(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.lock_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Application verrouillée',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Entrez votre PIN pour continuer',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildPinIndicator() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shake = _shakeController.isAnimating
            ? ((_shakeAnimation.value * 12) *
                ((_shakeAnimation.value * 10).toInt().isEven ? 1 : -1))
            : 0.0;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pinLength, (i) {
          final filled = i < _entered.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withValues(alpha: 0.15),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatusMessage() {
    if (_isLocked) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_rounded, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text(
              'Réessayez dans $_lockRemaining s',
              style: GoogleFonts.outfit(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _errorMessage!,
                style: GoogleFonts.outfit(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox(height: 40);
  }

  Widget _buildKeypad() {
    final digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          ...digits.map((row) => _buildKeypadRow(row)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biométrie ou vide
              _isBiometricAvailable
                  ? _KeypadButton(
                      onTap: _tryBiometric,
                      enabled: !_isLocked,
                      child: const Icon(Icons.fingerprint_rounded,
                          size: 28, color: Colors.white70),
                    )
                  : const SizedBox(width: 72, height: 72),
              _KeypadButton(
                label: '0',
                onTap: () => _onDigit('0'),
                enabled: !_isLocked,
              ),
              _KeypadButton(
                onTap: _onDelete,
                enabled: !_isLocked && _entered.isNotEmpty,
                child: const Icon(Icons.backspace_rounded,
                    size: 24, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (d) => _KeypadButton(
              label: d,
              onTap: () => _onDigit(d),
              enabled: !_isLocked,
            ),
          )
          .toList(),
    );
  }

  Widget _buildFooter() {
    return TextButton(
      onPressed: widget.onForceLogout,
      child: Text(
        'Changer de compte',
        style: GoogleFonts.outfit(
          color: Colors.white38,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white38,
        ),
      ),
    );
  }
}

// ─── Widget bouton clavier ──────────────────────────────────────────────────

class _KeypadButton extends StatefulWidget {
  final String? label;
  final Widget? child;
  final VoidCallback onTap;
  final bool enabled;

  const _KeypadButton({
    this.label,
    this.child,
    required this.onTap,
    this.enabled = true,
  }) : assert(label != null || child != null);

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: widget.enabled ? 0.08 : 0.03),
          border: Border.all(
            color: Colors.white.withValues(alpha: widget.enabled ? 0.12 : 0.04),
          ),
        ),
        child: Center(
          child: widget.label != null
              ? Text(
                  widget.label!,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: widget.enabled ? Colors.white : Colors.white24,
                  ),
                )
              : Opacity(
                  opacity: widget.enabled ? 1.0 : 0.3,
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}
