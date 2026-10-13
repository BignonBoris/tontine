import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/animated_bottom_sheet.dart';
import 'package:agent/core/widgets/client_pin_pad.dart';
import 'package:agent/core/widgets/slide_to_pay_button.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/withdrawals/data/services/agent_withdrawal_service.dart';
import 'package:agent/features/withdrawals/domain/entities/agent_pending_withdrawal.dart';
import 'package:agent/features/withdrawals/domain/entities/agent_withdrawal_preview.dart';
import 'package:agent/features/withdrawals/presentation/widgets/qr_scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Étapes du formulaire en mode Direct
// ─────────────────────────────────────────────────────────────────────────────
enum _DirectStep { form, confirm }
enum _PaymentMode { direct, reference, qrCode }

class AgentWithdrawalPaymentSheet extends StatefulWidget {
  const AgentWithdrawalPaymentSheet({super.key});

  @override
  State<AgentWithdrawalPaymentSheet> createState() =>
      _AgentWithdrawalPaymentSheetState();
}

class _AgentWithdrawalPaymentSheetState
    extends State<AgentWithdrawalPaymentSheet> {
  final _service = AgentWithdrawalService();

  // ── Mode sélectionné ──────────────────────────────────────────────────────
  _PaymentMode _mode = _PaymentMode.direct;

  // ── Mode Direct ───────────────────────────────────────────────────────────
  _DirectStep _directStep = _DirectStep.form;
  final _clientQueryController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isValidating = false; // spinner étape 1
  bool _isCreating = false;   // spinner création retrait
  bool _isPaying = false;     // spinner paiement OTP

  AgentWithdrawalPreview? _preview;     // résultat étape 1
  AgentPendingWithdrawal? _directWithdrawal; // retrait créé
  String? _directError;

  // ── Mode Référence ────────────────────────────────────────────────────────
  final _referenceController = TextEditingController();
  AgentPendingWithdrawal? _withdrawal;
  bool _isSearching = false;
  String? _refError;

  @override
  void dispose() {
    _clientQueryController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBottomSheet(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payer un retrait',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AgentAppTheme.textPrimaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => AnimatedBottomSheet.closeOf(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Sélecteur de mode (masqué sur l'étape 2 direct) ───────
              if (!(_mode == _PaymentMode.direct && _directStep == _DirectStep.confirm)) ...[
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_PaymentMode>(
                      segments: const [
                        ButtonSegment<_PaymentMode>(
                          value: _PaymentMode.direct,
                          label: Text('Direct'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment<_PaymentMode>(
                          value: _PaymentMode.reference,
                          label: Text('Référence'),
                          icon: Icon(Icons.tag),
                        ),
                        ButtonSegment<_PaymentMode>(
                          value: _PaymentMode.qrCode,
                          label: Text('QR Code'),
                          icon: Icon(Icons.qr_code_scanner),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (Set<_PaymentMode> v) {
                        setState(() {
                          _mode = v.first;
                          _directError = null;
                          _refError = null;
                          _directStep = _DirectStep.form;
                          _preview = null;
                          _directWithdrawal = null;
                          _withdrawal = null; // Réinitialiser le retrait pour la référence ou QR
                          _referenceController.clear();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Contenu selon le mode ──────────────────────────────────
              if (_mode == _PaymentMode.direct)
                _buildDirectContent()
              else if (_mode == _PaymentMode.reference)
                _buildRefContent()
              else
                _buildQrContent(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODE DIRECT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDirectContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _directStep == _DirectStep.form
          ? _buildDirectStep1()
          : _buildDirectStep2(),
    );
  }

  // ── Étape 1 : Saisie client + montant ─────────────────────────────────
  Widget _buildDirectStep1() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 1, total: 2, label: 'Informations du retrait'),
          const SizedBox(height: 20),

          // Champ client
          TextFormField(
            controller: _clientQueryController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\-+() a-zA-Z]'))],
            decoration: const InputDecoration(
              labelText: 'ID ou Téléphone du client',
              hintText: 'Ex : 22990000000',
              prefixIcon: Icon(Icons.person_search_rounded),
            ),
            onChanged: (_) => _clearDirectError(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ce champ est requis';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Champ montant
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Montant à retirer (F)',
              prefixIcon: Icon(Icons.payments_rounded),
            ),
            onChanged: (_) => _clearDirectError(),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Montant invalide';
              if (n % 100 != 0) return 'Doit être un multiple de 100 F';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Message d'erreur étape 1
          if (_directError != null) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: _directError!),
          ],

          const SizedBox(height: 24),

          // Bouton valider
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isValidating ? null : _validateStep1,
              icon: _isValidating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _isValidating ? 'Vérification...' : 'Continuer',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Étape 2 : Résumé + code OTP client ───────────────────────────────
  Widget _buildDirectStep2() {
    final w = _directWithdrawal;
    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIndicator(current: 2, total: 2, label: 'Code de confirmation'),
        const SizedBox(height: 16),

        // Résumé
        if (_preview != null) _DirectSummaryCard(preview: _preview!),
        if (w != null) ...[
          const SizedBox(height: 12),
          _WithdrawalCreatedCard(withdrawal: w),
        ],

        const SizedBox(height: 28),

        // Instruction
        Text(
          'Demandez au client son code de confirmation',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AgentAppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Faites saisir le code PIN personnel du client (4 chiffres) sur ce clavier sécurisé.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AgentAppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 24),

        // PIN pad
        if (w != null)
          ClientPinPad(
            pinLength: 4,
            scrambleKeypad: true,
            isError: _directError != null,
            errorMessage: _directError,
            isLoading: _isPaying,
            onPinEntered: (pin) => _payDirect(w.id, pin),
          ),

        const SizedBox(height: 16),

        // Retour
        Center(
          child: TextButton.icon(
            onPressed: _isPaying ? null : _backToStep1,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Modifier les informations'),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODE RÉFÉRENCE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRefContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _referenceController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: AgentInputRules.withdrawalReferenceFormatters,
          decoration: InputDecoration(
            labelText: 'Référence retrait',
            hintText: 'Ex. WDR-...',
            suffixIcon: IconButton(
              onPressed: _isSearching ? null : _searchByRef,
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
            ),
          ),
          onChanged: (_) {
            if (_refError != null) setState(() => _refError = null);
          },
          onSubmitted: (_) => _isSearching ? null : _searchByRef(),
        ),

        if (_withdrawal != null) ...[
          const SizedBox(height: 18),
          _WithdrawalSummaryCard(withdrawal: _withdrawal!),
          const SizedBox(height: 20),

          // Rappel de sécurité
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Identité vérifiée via l\'application client. Glissez pour confirmer le paiement.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_refError != null) ...[
            _ErrorBanner(message: _refError!),
            const SizedBox(height: 12),
          ],

          // Slider de confirmation
          SlideToPayButton(
            isLoading: _isPaying,
            label: 'Glisser pour payer',
            onConfirmed: () => _payRef(_withdrawal!.id),
          ),
        ],

        if (_refError != null && _withdrawal == null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: _refError!),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MODE QR CODE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildQrContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_withdrawal == null && _refError == null && !_isSearching)
          QrScannerView(
            onDetect: (code) {
              _referenceController.text = code;
              _searchByRef();
            },
          ),

        if (_isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(),
          ),

        if (_withdrawal != null) ...[
          const SizedBox(height: 8),
          _WithdrawalSummaryCard(withdrawal: _withdrawal!),
          const SizedBox(height: 20),

          // Rappel de sécurité
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA5D6A7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Identité vérifiée via QR Code. Glissez pour confirmer le paiement.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF1B5E20),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_refError != null) ...[
            _ErrorBanner(message: _refError!),
            const SizedBox(height: 12),
          ],

          // Slider de confirmation
          SlideToPayButton(
            isLoading: _isPaying,
            label: 'Glisser pour payer',
            onConfirmed: () => _payRef(_withdrawal!.id),
          ),
          
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _withdrawal = null;
                _refError = null;
                _referenceController.clear();
              });
            },
            icon: const Icon(Icons.qr_code_scanner, size: 16),
            label: const Text('Scanner un autre code'),
          ),
        ],

        if (_refError != null && _withdrawal == null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(message: _refError!),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _refError = null;
                _referenceController.clear();
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Réessayer'),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIQUE — Mode Direct
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _validateStep1() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isValidating = true;
      _directError = null;
    });

    try {
      // Étape 1 : prévisualiser (valide client + solde)
      final preview = await _service.previewDirectWithdrawal(
        clientQuery: _clientQueryController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
      );

      if (!mounted) return;

      setState(() {
        _preview = preview;
        _isValidating = false;
        _isCreating = true;
      });

      // Étape 1.5 : créer le retrait (envoie OTP au client)
      final withdrawal = await _service.createDirectWithdrawal(
        clientId: preview.clientId,
        amount: preview.amount,
      );

      if (!mounted) return;

      setState(() {
        _directWithdrawal = withdrawal;
        _isCreating = false;
        _directStep = _DirectStep.confirm;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _directError = e.message);
    } catch (_) {
      if (mounted) setState(() => _directError = 'Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  Future<void> _payDirect(String withdrawalId, String otp) async {
    setState(() {
      _isPaying = true;
      _directError = null;
    });
    try {
      await _service.payWithdrawal(
        withdrawalId: withdrawalId,
        pinCode: otp,
      );
      if (!mounted) return;
      AnimatedBottomSheet.closeOf(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _directError = e.message);
    } catch (_) {
      if (mounted) setState(() => _directError = 'Paiement échoué. Réessayez.');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  void _backToStep1() {
    setState(() {
      _directStep = _DirectStep.form;
      _preview = null;
      _directWithdrawal = null;
      _directError = null;
    });
  }

  void _clearDirectError() {
    if (_directError != null) setState(() => _directError = null);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGIQUE — Mode Référence
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _searchByRef() async {
    final reference = AgentInputRules.normalizeReference(
      _referenceController.text,
    );
    if (reference.isEmpty) {
      setState(() => _refError = 'Entrez une référence de retrait.');
      return;
    }

    setState(() {
      _isSearching = true;
      _withdrawal = null;
      _refError = null;
    });

    try {
      final withdrawal = await _service.searchByReference(reference);
      if (!mounted) return;
      setState(() => _withdrawal = withdrawal);
    } on ApiException catch (e) {
      if (mounted) setState(() => _refError = e.message);
    } catch (_) {
      if (mounted) setState(() => _refError = 'Recherche échouée. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _payRef(String withdrawalId) async {
    setState(() {
      _isPaying = true;
      _refError = null;
    });
    try {
      await _service.payWithdrawal(
        withdrawalId: withdrawalId,
      );
      if (!mounted) return;
      AnimatedBottomSheet.closeOf(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _refError = e.message);
    } catch (_) {
      if (mounted) setState(() => _refError = 'Paiement échoué. Réessayez.');
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS INTERNES
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final String label;

  const _StepIndicator({
    required this.current,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AgentAppTheme.primaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Étape $current / $total',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AgentAppTheme.textPrimaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _DirectSummaryCard extends StatelessWidget {
  final AgentWithdrawalPreview preview;

  const _DirectSummaryCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF388E3C), size: 18),
              const SizedBox(width: 6),
              Text(
                'Client vérifié',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF388E3C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Client', value: preview.clientDisplayName),
          _InfoRow(label: 'Téléphone', value: preview.clientPhoneNumber),
          _InfoRow(
            label: 'Montant',
            value: formatFcfa(preview.amount),
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCreatedCard extends StatelessWidget {
  final AgentPendingWithdrawal withdrawal;

  const _WithdrawalCreatedCard({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sms_rounded, color: Color(0xFFF57C00), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Faites saisir le code PIN (4 chiffres) au client pour valider ce retrait (réf. ${withdrawal.reference})',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF7B3F00),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalSummaryCard extends StatelessWidget {
  final AgentPendingWithdrawal withdrawal;

  const _WithdrawalSummaryCard({required this.withdrawal});

  @override
  Widget build(BuildContext context) {
    final expiresAt = withdrawal.confirmationCodeExpiresAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E7FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            withdrawal.reference,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AgentAppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Client', value: withdrawal.clientDisplayName ?? 'Non renseigné'),
          _InfoRow(label: 'Téléphone', value: withdrawal.clientPhoneNumber ?? 'Non renseigné'),
          _InfoRow(label: 'Montant', value: formatFcfa(withdrawal.amount), highlight: true),
          _InfoRow(
            label: 'Demandé le',
            value: DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(withdrawal.requestedAt),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AgentAppTheme.textSecondaryColor,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlight ? AgentAppTheme.secondaryColor : AgentAppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFB71C1C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB71C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
