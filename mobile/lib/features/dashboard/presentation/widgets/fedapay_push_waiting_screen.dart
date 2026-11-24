import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/data/services/tontine_fedapay_service.dart';

/// Ce que le client a choisi de faire en quittant l'ecran d'attente.
enum FedapayPushOutcome {
  /// Paiement confirme.
  succeeded,

  /// Renvoyer une nouvelle demande sur le telephone.
  retry,

  /// Payer via la page FedaPay (solution de secours).
  payOtherWay,

  /// Ecran ferme : en attente ou echec, rien d'autre a faire.
  closed,
}

/// Ecran affiche apres l'envoi d'un paiement Mobile Money sans redirection :
/// le client valide la demande sur son telephone, l'ecran suit le statut.
class FedapayPushWaitingScreen extends StatefulWidget {
  final TontineFedapayDepositIntent intent;
  final String operatorLabel;
  final TontineFedapayService? service;

  /// Delai avant d'autoriser un renvoi (aligne sur la limite de l'API).
  final Duration resendDelay;

  /// Au-dela, on arrete de suivre activement et on propose une alternative.
  final Duration waitTimeout;

  const FedapayPushWaitingScreen({
    super.key,
    required this.intent,
    required this.operatorLabel,
    this.service,
    this.resendDelay = const Duration(seconds: 30),
    this.waitTimeout = const Duration(minutes: 3),
  });

  static Future<FedapayPushOutcome> show(
    BuildContext context, {
    required TontineFedapayDepositIntent intent,
    required String operatorLabel,
  }) async {
    final outcome = await Navigator.of(context).push<FedapayPushOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FedapayPushWaitingScreen(
          intent: intent,
          operatorLabel: operatorLabel,
        ),
      ),
    );
    return outcome ?? FedapayPushOutcome.closed;
  }

  @override
  State<FedapayPushWaitingScreen> createState() =>
      _FedapayPushWaitingScreenState();
}

enum _PushViewState { waiting, succeeded, failed, timedOut }

class _FedapayPushWaitingScreenState extends State<FedapayPushWaitingScreen>
    with WidgetsBindingObserver {
  late final TontineFedapayService _service =
      widget.service ?? TontineFedapayService();
  // Compte par la minuterie (et non une horloge murale) : testable et coherent.
  int _elapsedSeconds = 0;
  Duration get _elapsed => Duration(seconds: _elapsedSeconds);
  Timer? _pollTimer;
  Timer? _tickTimer;
  bool _isChecking = false;
  _PushViewState _viewState = _PushViewState.waiting;
  String? _failureMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyIntent(widget.intent);
    if (_viewState == _PushViewState.waiting) {
      _startTracking();
    }
  }

  void _startTracking() {
    _stopTimers();
    _elapsedSeconds = 0;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkStatus(),
    );
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _elapsedSeconds++;
      if (_viewState == _PushViewState.waiting &&
          _elapsed >= widget.waitTimeout) {
        _stopTimers();
        setState(() => _viewState = _PushViewState.timedOut);
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Le client revient souvent de la fenetre de l'operateur : on verifie aussitot.
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
  }

  void _applyIntent(TontineFedapayDepositIntent intent) {
    if (intent.isSucceeded) {
      _stopTimers();
      _viewState = _PushViewState.succeeded;
    } else if (intent.isFailed) {
      _stopTimers();
      _viewState = _PushViewState.failed;
      _failureMessage = intent.failureMessage ??
          'Le paiement n\'a pas abouti. Vous pouvez reessayer.';
    }
  }

  Future<void> _checkStatus() async {
    if (_isChecking ||
        !mounted ||
        (_viewState != _PushViewState.waiting &&
            _viewState != _PushViewState.timedOut)) {
      return;
    }
    _isChecking = true;
    try {
      final intent = await _service.fetchDepositIntent(widget.intent.id);
      if (!mounted) return;
      setState(() => _applyIntent(intent));
    } catch (_) {
      // Erreur reseau passagere : on reessaie au prochain tour.
    } finally {
      _isChecking = false;
    }
  }

  void _close(FedapayPushOutcome outcome) {
    _stopTimers();
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close(_viewState == _PushViewState.succeeded
              ? FedapayPushOutcome.succeeded
              : FedapayPushOutcome.closed);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Fermer',
              icon: const Icon(Icons.close),
              onPressed: () => _close(
                _viewState == _PushViewState.succeeded
                    ? FedapayPushOutcome.succeeded
                    : FedapayPushOutcome.closed,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: switch (_viewState) {
              _PushViewState.waiting => _buildWaiting(),
              _PushViewState.succeeded => _buildSucceeded(),
              _PushViewState.failed => _buildFailed(),
              _PushViewState.timedOut => _buildTimedOut(),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting() {
    final remaining = widget.waitTimeout - _elapsed;
    final canResend = _elapsed >= widget.resendDelay;
    final resendIn = widget.resendDelay - _elapsed;
    final phone = widget.intent.pushPhoneMasked ?? 'votre numéro';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
        ),
        const SizedBox(height: 28),
        _title('Validez le paiement sur votre téléphone'),
        const SizedBox(height: 12),
        _body(
          'Une demande de ${_formatAmount(widget.intent.amount)} F a été envoyée '
          'au ${widget.operatorLabel} $phone.\n'
          'Saisissez votre code secret Mobile Money dans la fenêtre qui s\'affiche.',
        ),
        const SizedBox(height: 16),
        _hint(
          'Des frais opérateur peuvent s\'ajouter au montant. '
          'Temps restant : ${_formatDuration(remaining)}',
        ),
        const Spacer(),
        OutlinedButton(
          onPressed:
              canResend ? () => _close(FedapayPushOutcome.retry) : null,
          child: Text(
            canResend
                ? 'Rien reçu ? Renvoyer la demande'
                : 'Renvoyer la demande (${resendIn.inSeconds + 1} s)',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _close(FedapayPushOutcome.closed),
          child: const Text('Fermer'),
        ),
        _hint(
          'Si vous validez après avoir fermé cet écran, '
          'votre versement sera quand même pris en compte.',
        ),
      ],
    );
  }

  Widget _buildSucceeded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        _title('Paiement confirmé'),
        const SizedBox(height: 12),
        _body(
          '${_formatAmount(widget.intent.amount)} F ont été versés dans votre tontine.',
        ),
        const Spacer(),
        _primaryButton(
          'Terminer',
          () => _close(FedapayPushOutcome.succeeded),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.error_outline, color: Colors.red.shade400, size: 80),
        const SizedBox(height: 24),
        _title('Paiement non abouti'),
        const SizedBox(height: 12),
        _body(_failureMessage ?? 'Le paiement n\'a pas abouti.'),
        const Spacer(),
        _primaryButton('Réessayer', () => _close(FedapayPushOutcome.retry)),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _close(FedapayPushOutcome.payOtherWay),
          child: const Text('Payer autrement (page FedaPay)'),
        ),
        TextButton(
          onPressed: () => _close(FedapayPushOutcome.closed),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildTimedOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.hourglass_bottom, color: Colors.orange.shade400, size: 80),
        const SizedBox(height: 24),
        _title('Paiement toujours en attente'),
        const SizedBox(height: 12),
        _body(
          'Nous n\'avons pas encore reçu la confirmation de l\'opérateur. '
          'Si vous avez validé, votre versement apparaîtra dans quelques minutes.',
        ),
        const Spacer(),
        _primaryButton('Vérifier à nouveau', () {
          setState(() => _viewState = _PushViewState.waiting);
          _startTracking();
          _checkStatus();
        }),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _close(FedapayPushOutcome.retry),
          child: const Text('Renvoyer la demande'),
        ),
        TextButton(
          onPressed: () => _close(FedapayPushOutcome.closed),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _title(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryColor,
        ),
      );

  Widget _body(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 14,
          height: 1.5,
          color: AppTheme.textPrimaryColor,
        ),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 1.4,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      );

  Widget _primaryButton(String label, VoidCallback onPressed) => SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
        ),
      );

  static String _formatAmount(double amount) {
    final digits = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes;
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
