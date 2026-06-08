import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AgentClientFormSheet extends StatefulWidget {
  const AgentClientFormSheet({super.key});

  @override
  State<AgentClientFormSheet> createState() => _AgentClientFormSheetState();
}

class _AgentClientFormSheetState extends State<AgentClientFormSheet> {
  final _service = AgentClientService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _stakeController = TextEditingController();
  final _initialDepositController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
        top: 12,
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
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Nouveau client',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Fermer',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        inputFormatters: AgentInputRules.personNameFormatters,
                        decoration: const InputDecoration(labelText: 'Nom'),
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        validator: (value) {
                          if (value == null ||
                              !AgentInputRules.isValidPersonName(value)) {
                            return 'Entrez le nom';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        inputFormatters: AgentInputRules.personNameFormatters,
                        decoration: const InputDecoration(
                          labelText: 'Prénom(s)',
                        ),
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        validator: (value) {
                          if (value == null ||
                              !AgentInputRules.isValidPersonName(value)) {
                            return 'Entrez le(s) prenom(s)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                IntlPhoneField(
                  controller: _phoneController,
                  initialCountryCode: 'BJ',
                  showCountryFlag: true,
                  showDropdownIcon: false,
                  disableLengthCheck: true,
                  decoration: const InputDecoration(
                    labelText: 'Telephone',
                    hintText: 'Ex. 01 23 45 67 89',
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  validator: (value) {
                    if (value == null ||
                        !AgentInputRules.isValidPhone(value.number)) {
                      return 'Entrez un numero valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Adresse'),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return "Entrez l'adresse du client";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                  validator: _stakeValidator,
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
                      : const Text('Creer le client'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _stakeValidator(String? value) {
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
    final firstName = AgentInputRules.normalizePersonName(
      _firstNameController.text,
    );
    final lastName = AgentInputRules.normalizePersonName(
      _lastNameController.text,
    );

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final client = await _service.createClient(
        displayName: '$lastName $firstName'.trim(),
        phoneNumber: AgentInputRules.normalizePhone(_phoneController.text),
        address: _addressController.text.trim(),
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
      _showError("Le client n'a pas pu etre cree.");
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
