import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';

class ConfigureTontineStakeModal extends StatefulWidget {
  final Future<void> Function(double amount) onSubmit;

  const ConfigureTontineStakeModal({super.key, required this.onSubmit});

  @override
  State<ConfigureTontineStakeModal> createState() =>
      _ConfigureTontineStakeModalState();
}

class _ConfigureTontineStakeModalState
    extends State<ConfigureTontineStakeModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppTheme.primaryColor,
                        tooltip: "Fermer",
                        splashRadius: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Configurer votre mise",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Choisissez votre mise tontine. Elle doit etre un multiple de 500 et restera active jusqu'a la fin du cycle.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: AppInputRules.amountFormatters,
                    decoration: const InputDecoration(
                      labelText: "Mise par cycle",
                      hintText: "Ex: 1 000",
                      suffixText: "F CFA",
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      if (amount == null || amount <= 0) {
                        return "Entrez une mise valide.";
                      }
                      if (amount % 500 != 0) {
                        return "La mise doit etre un multiple de 500.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      "Un cycle est atteint quand votre cumul atteint mise x 31.",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      child: Text(
                        _isSubmitting
                            ? "Configuration..."
                            : "Commencer la tontine",
                      ),
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

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(double.parse(_amountController.text));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
