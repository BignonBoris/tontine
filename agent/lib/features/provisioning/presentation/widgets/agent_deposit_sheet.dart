import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/animated_bottom_sheet.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/cash/data/services/offline_sync_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:agent/features/provisioning/data/services/agent_provisioning_service.dart';
import 'package:flutter/material.dart';

class AgentDepositSheet extends StatefulWidget {
  final AgentClient client;

  const AgentDepositSheet({
    super.key,
    required this.client,
  });

  @override
  State<AgentDepositSheet> createState() => _AgentDepositSheetState();
}

class _AgentDepositSheetState extends State<AgentDepositSheet> {
  final _service = AgentProvisioningService();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return AnimatedBottomSheet(
      child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 20 : 20,
      ),
      child: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: SectionTitle(
                        title: 'Nouveau depot',
                        subtitle:
                            "Le depot sera debite de votre caisse puis credite sur la tontine active du client.",
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => AnimatedBottomSheet.closeOf(context, 'BACK'),
                      icon: const Icon(Icons.close_rounded),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AgentClientListTile(
                  client: widget.client,
                  trailing: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: AgentInputRules.amountFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    suffixText: 'F CFA',
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  validator: (value) {
                    final digits =
                        value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
                    final amount = int.tryParse(digits);
                    if (amount == null || amount <= 0) {
                      return 'Entrez un montant valide';
                    }
                    if (amount % AgentInputRules.financialAmountStep != 0) {
                      return 'Le montant doit etre un multiple de ${AgentInputRules.financialAmountStep}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire / reference',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _SheetErrorMessage(message: _errorMessage!),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer le depot'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (amount == null || amount <= 0) {
      _showError('Entrez un montant valide.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _service.createProvisioning(
        clientUserId: widget.client.id,
        amount: amount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      AnimatedBottomSheet.closeOf(context, true);
    } on ClockTamperingException catch (e) {
      // The device clock has been manipulated — refuse the transaction.
      _showError(e.message);
      if (mounted) setState(() => _isSubmitting = false);
    } on ChainIntegrityException {
      // The local transaction chain has been tampered with.
      _showError(
        'Anomalie de sécurité détectée : la file de transactions hors ligne a été modifiée. '
        'Contactez votre superviseur immédiatement.',
      );
      if (mounted) setState(() => _isSubmitting = false);
    } on ApiException catch (error) {
      _showError(error.message);
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    } catch (_) {
      _showError("Le dépôt n'a pas pu être enregistré.");
      if (mounted) {
        setState(() => _isSubmitting = false);
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

class _SheetErrorMessage extends StatelessWidget {
  final String message;

  const _SheetErrorMessage({required this.message});

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
        style: const TextStyle(
          color: Color(0xFFB71C1C),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}
