import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/withdrawals/data/services/agent_withdrawal_service.dart';
import 'package:agent/features/withdrawals/domain/entities/agent_pending_withdrawal.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AgentWithdrawalPaymentSheet extends StatefulWidget {
  const AgentWithdrawalPaymentSheet({super.key});

  @override
  State<AgentWithdrawalPaymentSheet> createState() =>
      _AgentWithdrawalPaymentSheetState();
}

class _AgentWithdrawalPaymentSheetState
    extends State<AgentWithdrawalPaymentSheet> {
  final _service = AgentWithdrawalService();
  final _referenceController = TextEditingController();
  final _confirmationCodeController = TextEditingController();
  AgentPendingWithdrawal? _withdrawal;
  bool _isSearching = false;
  bool _isPaying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _referenceController.dispose();
    _confirmationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 24,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(width: 44, child: Divider(thickness: 4)),
              ),
              const SizedBox(height: 12),
              const SectionTitle(
                title: 'Payer un retrait',
                subtitle:
                    "Recherchez le retrait par reference, puis saisissez le code communique par le client.",
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Reference retrait',
                  hintText: 'Ex. WDR-...',
                  suffixIcon: IconButton(
                    onPressed: _isSearching ? null : _search,
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
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                onSubmitted: (_) => _isSearching ? null : _search(),
              ),
              if (_withdrawal != null) ...[
                const SizedBox(height: 18),
                _WithdrawalSummaryCard(withdrawal: _withdrawal!),
                const SizedBox(height: 14),
                if (_withdrawal!.isConfirmationCodeExpired)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Text(
                      "Le code a expire. Demandez au client d'en generer un nouveau avant le paiement.",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: const Color(0xFF8A5100),
                      ),
                    ),
                  ),
                TextField(
                  controller: _confirmationCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Code de confirmation client',
                    hintText: 'Code a 6 chiffres',
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _InlineErrorMessage(message: _errorMessage!),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isPaying || _withdrawal!.isConfirmationCodeExpired
                      ? null
                      : _payWithdrawal,
                  child: _isPaying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Valider le paiement'),
                ),
              ],
              if (_withdrawal == null && _errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineErrorMessage(message: _errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _search() async {
    final reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      _showError('Entrez une reference de retrait.');
      return;
    }

    setState(() {
      _isSearching = true;
      _withdrawal = null;
      _errorMessage = null;
    });

    try {
      final withdrawal = await _service.searchByReference(reference);
      if (!mounted) {
        return;
      }
      setState(() {
        _withdrawal = withdrawal;
      });
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError("La recherche du retrait a echoue.");
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _payWithdrawal() async {
    if (_withdrawal == null) {
      _showError('Recherchez d abord un retrait valide.');
      return;
    }
    if (_withdrawal!.isConfirmationCodeExpired) {
      _showError(
        "Le code a expire. Demandez au client d'en generer un nouveau.",
      );
      return;
    }

    final confirmationCode = _confirmationCodeController.text.trim();
    if (confirmationCode.length < 4) {
      _showError('Entrez le code de confirmation du client.');
      return;
    }

    setState(() {
      _isPaying = true;
      _errorMessage = null;
    });
    try {
      await _service.payWithdrawal(
        withdrawalId: _withdrawal!.id,
        confirmationCode: confirmationCode,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showError(error.message);
      if (mounted) {
        setState(() => _isPaying = false);
      }
    } catch (_) {
      _showError("Le paiement du retrait a echoue.");
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = message);
  }
}

class _InlineErrorMessage extends StatelessWidget {
  final String message;

  const _InlineErrorMessage({required this.message});

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
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFB71C1C),
        ),
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
          _InfoLine(
            label: 'Client',
            value: withdrawal.clientDisplayName ?? 'Non renseigne',
          ),
          _InfoLine(
            label: 'Telephone',
            value: withdrawal.clientPhoneNumber ?? 'Non renseigne',
          ),
          _InfoLine(
            label: 'Montant',
            value: formatFcfa(withdrawal.amount),
            isHighlighted: true,
          ),
          _InfoLine(
            label: 'Demande le',
            value: DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(
              withdrawal.requestedAt,
            ),
          ),
          if (expiresAt != null)
            _InfoLine(
              label: 'Code valable jusqu au',
              value: DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(expiresAt),
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _InfoLine({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
                color: isHighlighted
                    ? AgentAppTheme.secondaryColor
                    : AgentAppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
