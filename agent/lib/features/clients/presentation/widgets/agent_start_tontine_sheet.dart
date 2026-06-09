import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:flutter/material.dart';

class AgentStartTontineSheet extends StatefulWidget {
  final AgentClient client;

  const AgentStartTontineSheet({
    super.key,
    required this.client,
  });

  @override
  State<AgentStartTontineSheet> createState() => _AgentStartTontineSheetState();
}

class _AgentStartTontineSheetState extends State<AgentStartTontineSheet> {
  final _service = AgentClientService();
  final _stakeController = TextEditingController();
  final _initialDepositController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _stakeController.dispose();
    _initialDepositController.dispose();
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
                  child: SizedBox(width: 44, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 12),
                const SectionTitle(
                  title: 'Demarrer une tontine',
                  subtitle:
                      'Definissez la mise du client et ajoutez un premier depot si necessaire.',
                ),
                const SizedBox(height: 16),
                AgentClientListTile(client: widget.client),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _stakeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: AgentInputRules.amountFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Mise initiale',
                    suffixText: 'F CFA',
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  validator: _amountValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _initialDepositController,
                  keyboardType: TextInputType.number,
                  inputFormatters: AgentInputRules.amountFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Premier depot (facultatif)',
                    suffixText: 'F CFA',
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  validator: _optionalAmountValidator,
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
                      : const Text('Demarrer la tontine'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _amountValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final amount = int.tryParse(digits);
    if (amount == null || amount <= 0) {
      return 'Entrez une mise valide';
    }
    if (amount % 500 != 0) {
      return 'La mise doit etre un multiple de 500';
    }
    return null;
  }

  String? _optionalAmountValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (digits.isEmpty) {
      return null;
    }
    final amount = int.tryParse(digits);
    if (amount == null || amount < 0) {
      return 'Montant invalide';
    }
    if (amount % 500 != 0) {
      return 'Le depot doit etre un multiple de 500';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final stakeAmount = double.parse(
      _stakeController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final initialDigits = _initialDepositController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final double initialDeposit = initialDigits.isEmpty
        ? 0
        : double.parse(initialDigits);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final client = await _service.startTontine(
        clientId: widget.client.id,
        stakeAmount: stakeAmount,
        initialDeposit: initialDeposit,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(client);
    } on ApiException catch (error) {
      _showError(error.message);
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    } catch (_) {
      _showError("La tontine n'a pas pu etre demarree.");
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
