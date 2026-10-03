import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/features/clients/data/services/offline_kyc_service.dart';
import 'package:agent/core/network/api_client.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AgentClientEnrollmentScreen extends StatefulWidget {
  const AgentClientEnrollmentScreen({super.key});

  @override
  State<AgentClientEnrollmentScreen> createState() =>
      _AgentClientEnrollmentScreenState();
}

class _AgentClientEnrollmentScreenState
    extends State<AgentClientEnrollmentScreen> {
  int _currentStep = 0;
  final _offlineKycService = OfflineKycService();

  // Form Keys
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _stepTontineFormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  // Niveau 0 : Informations de base
  String _lastName = '';
  String _firstName = '';
  String _phoneNumber = '';

  // Niveau 1 : KYC
  String? _documentType;
  String? _documentNumber;
  File? _frontImage;
  File? _backImage;
  File? _selfieImage;

  // Niveau Tontine
  double _stakeAmount = 100.0;

  // Niveau Sécurité
  String _pinCode = '';
  final _pinController = TextEditingController();

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        if (type == 'front') _frontImage = File(pickedFile.path);
        if (type == 'back') _backImage = File(pickedFile.path);
        if (type == 'selfie') _selfieImage = File(pickedFile.path);
      });
    }
  }

  Widget _buildImageSelector(String title, File? image, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _pickImage(ImageSource.camera, type),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(image, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: Colors.grey[600], size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Ajouter $title',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTrustReassuranceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgentAppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AgentAppTheme.primaryColor.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.privacy_tip_outlined,
            color: AgentAppTheme.primaryColor,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sécurisé et Conforme APDP',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AgentAppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vos documents d\'identité sont chiffrés de bout en bout et traités conformément aux dispositions de l\'APDP au Bénin et des réglementations BCEAO.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finalizeEnrollment() async {
    setState(() => _isLoading = true);
    
    try {
      await _offlineKycService.saveEnrollment(
        lastName: _lastName,
        firstName: _firstName,
        phoneNumber: _phoneNumber,
        pinCode: _pinCode,
        documentType: _documentType,
        documentNumber: _documentNumber,
        frontImagePath: _frontImage?.path,
        backImagePath: _backImage?.path,
        selfiePath: _selfieImage?.path,
        stakeAmount: _stakeAmount,
      );

      // Tentative de synchronisation immédiate si l'agent est connecté
      bool isSynced = false;
      try {
        await _offlineKycService.syncPendingEnrollments(ApiClient());
        isSynced = true;
      } catch (e) {
        print('Pas de connexion ou échec de synchronisation immédiate: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSynced 
              ? 'Enrôlement sauvegardé et synchronisé !' 
              : 'Enrôlement sauvegardé en local (en attente de réseau) !'),
            backgroundColor: isSynced ? Colors.green : Colors.orange,
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

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_step1FormKey.currentState!.validate()) {
        _step1FormKey.currentState!.save();
        setState(() => _currentStep += 1);
      }
    } else if (_currentStep == 1) {
      // Si on clique sur "Continuer", on EXIGE que le KYC soit rempli.
      if (_documentType == null ||
          (_documentNumber == null || _documentNumber!.isEmpty) ||
          _frontImage == null ||
          (_documentType != 'passport' && _backImage == null) ||
          _selfieImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez fournir toutes les pièces pour valider le KYC, ou cliquez sur "Ignorer".'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        _step2FormKey.currentState!.save();
        setState(() => _currentStep += 1);
      }
    } else if (_currentStep == 2) {
      if (_stepTontineFormKey.currentState!.validate()) {
        _stepTontineFormKey.currentState!.save();
        setState(() => _currentStep += 1);
      }
    } else if (_currentStep == 3) {
      if (_step3FormKey.currentState!.validate()) {
        _step3FormKey.currentState!.save();
        _finalizeEnrollment();
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  List<Step> _getSteps() {
    return [
      Step(
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 0,
        title: const Text('Identité'),
        subtitle: const Text('Niveau 0 (Requis)'),
        content: Form(
          key: _step1FormKey,
          child: Column(
            children: [
              TextFormField(
                initialValue: _lastName,
                decoration: const InputDecoration(
                  labelText: 'Nom de famille',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.name,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                ],
                validator: (v) => v == null || v.isEmpty ? 'Ce champ est requis' : null,
                onSaved: (v) => _lastName = v!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _firstName,
                decoration: const InputDecoration(
                  labelText: 'Prénom(s)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.name,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
                ],
                validator: (v) => v == null || v.isEmpty ? 'Ce champ est requis' : null,
                onSaved: (v) => _firstName = v!.trim(),
              ),
              const SizedBox(height: 16),
              IntlPhoneField(
                initialCountryCode: 'BJ',
                showCountryFlag: true,
                showDropdownIcon: false,
                disableLengthCheck: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone (Optionnel)',
                  border: OutlineInputBorder(),
                  helperText: 'Nécessaire pour se connecter à l\'app',
                ),
                onSaved: (phone) {
                  if (phone != null && phone.number.isNotEmpty) {
                    _phoneNumber = phone.completeNumber;
                  } else {
                    _phoneNumber = '';
                  }
                },
              ),
            ],
          ),
        ),
      ),
      Step(
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 1,
        title: const Text('Documents'),
        subtitle: const Text('Niveau 1 (Optionnel)'),
        content: Form(
          key: _step2FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Remplissez ces informations pour un compte complet. Vous pouvez également ignorer cette étape.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Type de pièce',
                  border: OutlineInputBorder(),
                ),
                value: _documentType,
                items: const [
                  DropdownMenuItem(value: 'cni', child: Text('Carte d\'identité')),
                  DropdownMenuItem(value: 'passport', child: Text('Passeport')),
                  DropdownMenuItem(value: 'residence_permit', child: Text('Carte de séjour')),
                ],
                onChanged: (val) {
                  setState(() {
                    _documentType = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _documentNumber,
                decoration: const InputDecoration(
                  labelText: 'Numéro de la pièce',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => _documentNumber = v,
                onSaved: (v) => _documentNumber = v,
              ),
              const SizedBox(height: 16),
              _buildImageSelector('Recto de la pièce', _frontImage, 'front'),
              if (_documentType != 'passport')
                _buildImageSelector('Verso de la pièce', _backImage, 'back'),
              _buildImageSelector('Selfie', _selfieImage, 'selfie'),
            ],
          ),
        ),
      ),
      Step(
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 2,
        title: const Text('Tontine'),
        subtitle: const Text('Configuration'),
        content: Form(
          key: _stepTontineFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configurez la mise de la tontine du client. Minimum 100 FCFA.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _stakeAmount.toStringAsFixed(0),
                decoration: const InputDecoration(
                  labelText: 'Mise (FCFA)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.money),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'La mise est requise';
                  final value = double.tryParse(v);
                  if (value == null || value < 100) {
                    return 'La mise doit être d\'au moins 100 FCFA';
                  }
                  return null;
                },
                onSaved: (v) {
                  if (v != null && v.isNotEmpty) {
                    _stakeAmount = double.parse(v);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      Step(
        state: _currentStep > 3 ? StepState.complete : StepState.indexed,
        isActive: _currentStep >= 3,
        title: const Text('Sécurité'),
        subtitle: const Text('Code PIN'),
        content: Form(
          key: _step3FormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agent, veuillez tendre l\'appareil au client.\nClient, veuillez définir un code à 4 chiffres pour sécuriser vos futurs retraits.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _pinController,
                decoration: const InputDecoration(
                  labelText: 'Code PIN secret (4 chiffres)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Le code PIN est requis';
                  if (v.length != 4 || int.tryParse(v) == null) {
                    return 'Le code PIN doit contenir exactement 4 chiffres';
                  }
                  return null;
                },
                onSaved: (v) => _pinCode = v!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Confirmer le Code PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                validator: (v) {
                  if (v != _pinController.text) {
                    return 'Les codes PIN ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildTrustReassuranceCard(),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvel Enrôlement'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              onStepTapped: (step) {
                // Allows tapping back to previous steps without validation
                if (step < _currentStep) {
                  setState(() => _currentStep = step);
                }
              },
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                final isLastStep = _currentStep == _getSteps().length - 1;
                final isKycStep = _currentStep == 1;

                return Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AgentAppTheme.primaryColor,
                          ),
                          child: Text(
                            isLastStep ? 'Terminer' : 'Continuer',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      if (isKycStep) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Skip logic: just clear KYC fields and move on
                              setState(() {
                                _documentType = null;
                                _documentNumber = null;
                                _frontImage = null;
                                _backImage = null;
                                _selfieImage = null;
                                _currentStep += 1;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Ignorer'),
                          ),
                        ),
                      ] else if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: details.onStepCancel,
                            child: const Text('Retour'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: _getSteps(),
            ),
    );
  }
}
