import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/features/groups/data/services/agent_group_service.dart';
import 'package:agent/features/groups/domain/entities/agent_group.dart';
import 'package:flutter/material.dart';

class AgentGroupFormSheet extends StatefulWidget {
  final AgentGroup? initialGroup;

  const AgentGroupFormSheet({super.key, this.initialGroup});

  @override
  State<AgentGroupFormSheet> createState() => _AgentGroupFormSheetState();
}

class _AgentGroupFormSheetState extends State<AgentGroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _service = AgentGroupService();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _participantCountController;
  late final TextEditingController _turnIntervalValueController;
  late final TextEditingController _contributionAmountController;
  late final TextEditingController _commissionAmountController;
  late final TextEditingController _plannedStartDateController;
  DateTime? _plannedStartDate;
  String _turnIntervalUnit = 'month';
  bool _submitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialGroup != null;

  @override
  void initState() {
    super.initState();
    final initialGroup = widget.initialGroup;
    _nameController = TextEditingController(text: initialGroup?.name ?? '');
    _descriptionController = TextEditingController(
      text: initialGroup?.description ?? '',
    );
    _participantCountController = TextEditingController(
      text: initialGroup != null ? initialGroup.participantCount.toString() : '2',
    );
    _turnIntervalValueController = TextEditingController(
      text: initialGroup != null ? initialGroup.turnIntervalValue.toString() : '1',
    );
      _contributionAmountController = TextEditingController(
        text: initialGroup != null
            ? initialGroup.contributionAmount.toStringAsFixed(0)
            : AgentInputRules.financialAmountStep.toString(),
      );
    _commissionAmountController = TextEditingController(
      text: initialGroup != null
          ? initialGroup.commissionAmount.toStringAsFixed(0)
          : '50',
    );
    _turnIntervalUnit = initialGroup?.turnIntervalUnit ?? 'month';
    _plannedStartDate =
        initialGroup?.plannedStartDate ??
        DateTime.now().add(const Duration(days: 7));
    _plannedStartDateController = TextEditingController(
      text: _formatDate(_plannedStartDate!),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _participantCountController.dispose();
    _turnIntervalValueController.dispose();
    _contributionAmountController.dispose();
    _commissionAmountController.dispose();
    _plannedStartDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing ? 'Modifier le groupe' : 'Nouveau groupe',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                    validator: (value) {
                      final normalized = (value ?? '').trim();
                      if (normalized.isEmpty) {
                        return 'Le nom du groupe est requis.';
                      }
                      if (normalized.length < 3 || normalized.length > 160) {
                        return 'Le nom doit contenir entre 3 et 160 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descriptionController,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length > 255) {
                        return 'La description ne doit pas depasser 255 caracteres.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _participantCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nombre cible de participants',
                      prefixIcon: Icon(Icons.group_outlined),
                    ),
                    validator: (value) {
                      final parsed = int.tryParse((value ?? '').trim());
                      if (parsed == null || parsed < 2) {
                        return 'Entrez au moins 2 participants.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _turnIntervalValueController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Delai d un tour',
                            prefixIcon: Icon(Icons.timelapse_rounded),
                          ),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            if (parsed == null || parsed < 1) {
                              return 'Entrez une valeur >= 1.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _turnIntervalUnit,
                          decoration: const InputDecoration(labelText: 'Unite'),
                          items: const [
                            DropdownMenuItem(value: 'day', child: Text('Jour(s)')),
                            DropdownMenuItem(
                              value: 'week',
                              child: Text('Semaine(s)'),
                            ),
                            DropdownMenuItem(value: 'month', child: Text('Mois')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _turnIntervalUnit = value ?? 'month';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _contributionAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Montant par personne et par tour',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').trim());
                      if (
                        parsed == null ||
                        parsed <= 0 ||
                        parsed % AgentInputRules.financialAmountStep != 0
                      ) {
                        return 'Entrez un multiple positif de ${AgentInputRules.financialAmountStep}.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _commissionAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Commission totale du groupe par tour',
                      prefixIcon: const Icon(Icons.percent_rounded),
                      helperText: _commissionHelperText(),
                    ),
                    validator: (value) {
                      final contribution = double.tryParse(
                        _contributionAmountController.text.trim(),
                      );
                      final parsed = double.tryParse((value ?? '').trim());
                      if (parsed == null || parsed <= 0 || parsed % 1 != 0) {
                        return 'Entrez un montant de commission entier.';
                      }
                      if (contribution == null || contribution <= 0) {
                        return 'Renseignez d abord la mise par personne.';
                      }
                      final minCommission = _commissionMin(contribution);
                      final maxCommission = _commissionMax(contribution);
                      if (parsed < minCommission || parsed > maxCommission) {
                        return 'La commission doit etre comprise entre ${formatFcfa(minCommission)} et ${formatFcfa(maxCommission)}.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _plannedStartDateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date de debut envisagee',
                      prefixIcon: Icon(Icons.event_rounded),
                    ),
                    onTap: _pickPlannedStartDate,
                    validator: (_) {
                      if (_plannedStartDate == null) {
                        return 'Choisissez une date de debut envisagee.';
                      }
                      return null;
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons.save_outlined
                                  : Icons.add_circle_outline_rounded,
                            ),
                      label: Text(_isEditing ? 'Enregistrer' : 'Creer le groupe'),
                    ),
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

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final participantCount = int.parse(_participantCountController.text.trim());
      final turnIntervalValue = int.parse(_turnIntervalValueController.text.trim());
      final contributionAmount = double.parse(
        _contributionAmountController.text.trim(),
      );
      final commissionAmount = double.parse(
        _commissionAmountController.text.trim(),
      );

      final result = _isEditing
          ? await _service.updateGroup(
              groupId: widget.initialGroup!.id,
              name: name,
              participantCount: participantCount,
              turnIntervalValue: turnIntervalValue,
              turnIntervalUnit: _turnIntervalUnit,
              contributionAmount: contributionAmount,
              commissionAmount: commissionAmount,
              plannedStartDate: _plannedStartDate!.toIso8601String(),
              description: description.isEmpty ? null : description,
            )
          : await _service.createGroup(
              name: name,
              participantCount: participantCount,
              turnIntervalValue: turnIntervalValue,
              turnIntervalUnit: _turnIntervalUnit,
              contributionAmount: contributionAmount,
              commissionAmount: commissionAmount,
              plannedStartDate: _plannedStartDate!.toIso8601String(),
              description: description.isEmpty ? null : description,
            );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _pickPlannedStartDate() async {
    final now = DateTime.now();
    final initialDate = _plannedStartDate ?? now.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initialDate,
      locale: const Locale('fr', 'FR'),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _plannedStartDate = picked;
      _plannedStartDateController.text = _formatDate(picked);
    });
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  double _commissionMin(double contributionAmount) {
    return double.parse((contributionAmount * 0.1).toStringAsFixed(0));
  }

  double _commissionMax(double contributionAmount) {
    return double.parse((contributionAmount * 0.5).toStringAsFixed(0));
  }

  String _commissionHelperText() {
    final contribution = double.tryParse(_contributionAmountController.text.trim());
    if (contribution == null || contribution <= 0) {
      return 'Saisissez la mise pour calculer la borne.';
    }
    final minCommission = _commissionMin(contribution);
    final maxCommission = _commissionMax(contribution);
    return 'Entre ${formatFcfa(minCommission)} et ${formatFcfa(maxCommission)} par tour. Repartition: 25% plateforme / 75% agent.';
  }
}
