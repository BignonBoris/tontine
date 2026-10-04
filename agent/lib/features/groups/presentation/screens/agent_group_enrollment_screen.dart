import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/features/groups/data/services/agent_group_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AgentGroupEnrollmentScreen extends StatefulWidget {
  const AgentGroupEnrollmentScreen({super.key});

  @override
  State<AgentGroupEnrollmentScreen> createState() => _AgentGroupEnrollmentScreenState();
}

class _AgentGroupEnrollmentScreenState extends State<AgentGroupEnrollmentScreen> {
  final _service = AgentGroupService();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Informations
  final _step1Key = GlobalKey<FormState>();
  final _participantCountController = TextEditingController(text: '2');
  final _contributionAmountController = TextEditingController(
    text: AgentInputRules.financialAmountStep.toString(),
  );
  final _commissionAmountController = TextEditingController(text: '10');
  final _turnIntervalValueController = TextEditingController(text: '1');
  String _turnIntervalUnit = 'month';

  // Step 2: Finalisation
  final _step2Key = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _plannedStartDate = DateTime.now().add(const Duration(days: 7));
  late final TextEditingController _plannedStartDateController;

  @override
  void initState() {
    super.initState();
    _plannedStartDateController = TextEditingController(text: _formatDate(_plannedStartDate));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plannedStartDateController.dispose();
    _participantCountController.dispose();
    _contributionAmountController.dispose();
    _commissionAmountController.dispose();
    _turnIntervalValueController.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
      
      // Auto-generate name if empty
      if (_nameController.text.trim().isEmpty) {
        final amount = double.tryParse(_contributionAmountController.text.trim()) ?? 0;
        final interval = int.tryParse(_turnIntervalValueController.text.trim()) ?? 1;
        final unitLabel = _turnIntervalUnit == 'day' 
            ? 'Jour' 
            : _turnIntervalUnit == 'week' 
                ? 'Semaine' 
                : 'Mois';
        
        final formattedAmount = formatFcfa(amount);
        String name = 'Tontine $formattedAmount / ';
        if (interval == 1) {
          name += unitLabel;
        } else {
          name += '$interval ${unitLabel}s';
        }
        _nameController.text = name;
      }
      
      setState(() => _currentStep += 1);
    } else if (_currentStep == 1) {
      if (!_step2Key.currentState!.validate()) return;
      _submitForm();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitForm() async {
    setState(() => _isLoading = true);
    try {
      await _service.createGroup(
        name: _nameController.text.trim(),
        participantCount: int.parse(_participantCountController.text.trim()),
        turnIntervalValue: int.parse(_turnIntervalValueController.text.trim()),
        turnIntervalUnit: _turnIntervalUnit,
        contributionAmount: double.parse(_contributionAmountController.text.trim()),
        commissionAmount: double.parse(_commissionAmountController.text.trim()),
        plannedStartDate: _plannedStartDate.toIso8601String(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Groupe créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plannedStartDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _plannedStartDate = picked;
        _plannedStartDateController.text = _formatDate(picked);
      });
    }
  }

  String _commissionHelperText() {
    final contribution = double.tryParse(_contributionAmountController.text.trim());
    if (contribution == null || contribution <= 0) return '';
    
    final commission = double.tryParse(_commissionAmountController.text.trim());
    if (commission == null || commission < 0) return '';
    
    final totalPot = contribution * (int.tryParse(_participantCountController.text.trim()) ?? 2);
    final ratio = (commission / totalPot) * 100;
    return 'Soit ~${ratio.toStringAsFixed(1)}% du pot total (${formatFcfa(totalPot)})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un groupe'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              onStepTapped: (step) => setState(() => _currentStep = step),
              controlsBuilder: (context, details) {
                final isLast = _currentStep == 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(isLast ? 'Créer' : 'Continuer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: details.onStepCancel,
                          child: Text(_currentStep == 0 ? 'Annuler' : 'Retour'),
                        ),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Structure et cadence'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _step1Key,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _participantCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nombre cible de participants',
                            prefixIcon: Icon(Icons.group_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final parsed = int.tryParse((value ?? '').trim());
                            if (parsed == null || parsed < 2) return 'Min. 2 participants';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contributionAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Montant par personne / tour',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final parsed = double.tryParse((value ?? '').trim());
                            if (parsed == null || parsed <= 0 || parsed % AgentInputRules.financialAmountStep != 0) {
                              return 'Multiple de ${AgentInputRules.financialAmountStep} requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _commissionAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Commission du groupe par tour',
                            prefixIcon: const Icon(Icons.percent_rounded),
                            helperText: _commissionHelperText(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final parsed = double.tryParse((value ?? '').trim());
                            if (parsed == null || parsed < 0) return 'Montant invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _turnIntervalValueController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Délai',
                                  prefixIcon: Icon(Icons.timelapse_rounded),
                                ),
                                validator: (value) {
                                  final parsed = int.tryParse((value ?? '').trim());
                                  if (parsed == null || parsed < 1) return '>= 1';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _turnIntervalUnit,
                                decoration: const InputDecoration(labelText: 'Unité'),
                                items: const [
                                  DropdownMenuItem(value: 'day', child: Text('Jour(s)')),
                                  DropdownMenuItem(value: 'week', child: Text('Semaine(s)')),
                                  DropdownMenuItem(value: 'month', child: Text('Mois')),
                                ],
                                onChanged: (value) => setState(() => _turnIntervalUnit = value ?? 'month'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text('Finalisation'),
                  isActive: _currentStep >= 1,
                  content: Form(
                    key: _step2Key,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nom du groupe',
                            prefixIcon: Icon(Icons.groups_2_outlined),
                          ),
                          validator: (value) {
                            final normalized = (value ?? '').trim();
                            if (normalized.isEmpty) return 'Requis';
                            if (normalized.length < 3) return 'Trop court (min 3)';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _plannedStartDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date de début prévue',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                          onTap: _pickStartDate,
                          validator: (_) {
                            if (_plannedStartDate == null) {
                              return 'Choisissez une date de début prévue.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
