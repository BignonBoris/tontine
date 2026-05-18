import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(
                    width: 44,
                    child: Divider(thickness: 4),
                  ),
                ),
                const SizedBox(height: 12),
                const SectionTitle(
                  title: 'Nouveau depot',
                  subtitle:
                      "Le depot sera debite de votre caisse puis credite sur la tontine active du client.",
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
                    if (amount % 500 != 0) {
                      return 'Le montant doit etre un multiple de 500';
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
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showError(error.message);
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    } catch (_) {
      _showError("Le depot n'a pas pu etre enregistre.");
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
