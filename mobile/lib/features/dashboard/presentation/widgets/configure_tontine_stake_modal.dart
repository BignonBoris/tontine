import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/features/dashboard/domain/entities/user_profile.dart';
import 'package:mobile/features/dashboard/presentation/screens/kyc_submission_screen.dart';

class ConfigureTontineStakeModal extends StatefulWidget {
  final Future<void> Function(double amount, bool termsAccepted) onSubmit;
  final double? maxDailyStakeLimit;
  final String? kycStatus;
  final String? kycLabel;

  const ConfigureTontineStakeModal({
    super.key,
    required this.onSubmit,
    this.maxDailyStakeLimit,
    this.kycStatus,
    this.kycLabel,
  });

  @override
  State<ConfigureTontineStakeModal> createState() =>
      _ConfigureTontineStakeModalState();
}

class _ConfigureTontineStakeModalState
    extends State<ConfigureTontineStakeModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  bool _termsAccepted = false;

  double get _effectiveLimit {
    if (widget.maxDailyStakeLimit != null && widget.maxDailyStakeLimit! > 0) {
      return widget.maxDailyStakeLimit!;
    }
    final status = (widget.kycStatus ?? 'unverified').toLowerCase();
    if (status == 'verified') {
      return 50000;
    } else if (status == 'pending_review') {
      return 10000;
    }
    return 2000;
  }

  bool get _isVerified =>
      (widget.kycStatus ?? 'unverified').toLowerCase() == 'verified';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLimit = _effectiveLimit;
    final isVerified = _isVerified;

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
                  color: Colors.black.withValues(alpha: 0.08),
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
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
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
                  const SizedBox(height: 8),
                  Text(
                    "Choisissez votre mise tontine journalière (multiple de ${AppInputRules.financialAmountStep} F). Elle sera active pour les 31 jours du cycle.",
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppTheme.textSecondaryColor,
                      height: 1.45,
                    ),
                  ),

                  // KYC Limit Indicator Card
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isVerified
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isVerified
                                  ? Icons.verified_user_rounded
                                  : Icons.shield_outlined,
                              color: isVerified
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFD97706),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isVerified
                                    ? "Identité certifiée • Plafond : ${formatFCFA(effectiveLimit)} F / jour"
                                    : "Plafond KYC actuel : ${formatFCFA(effectiveLimit)} F CFA / jour",
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isVerified
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isVerified) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Réglementation SFD : les mises sont limitées pour les comptes non vérifiés.",
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFFB45309),
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => KycSubmissionScreen(
                                    currentStatus: KycSummary(
                                      status: widget.kycStatus ?? 'unverified',
                                      level: 'basic',
                                    ),
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "Augmenter mes plafonds (Vérification KYC)",
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: AppTheme.primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: AppInputRules.amountFormatters,
                    decoration: InputDecoration(
                      labelText: "Mise par cycle",
                      hintText: "Ex: 1 000",
                      suffixText: "F CFA",
                      helperText: "Max autorisé : ${formatFCFA(effectiveLimit)} F CFA",
                      helperStyle: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      if (amount == null || amount <= 0) {
                        return "Entrez une mise valide.";
                      }
                      if (amount % AppInputRules.financialAmountStep != 0) {
                        return "La mise doit être un multiple de ${AppInputRules.financialAmountStep}.";
                      }
                      if (amount > effectiveLimit) {
                        return "Plafond KYC dépassé (max ${formatFCFA(effectiveLimit)} F). Validez votre KYC pour débloquer plus.";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "À la fin des 31 jours, 30 mises vous sont reversées et 1 mise est retenue en frais de tenue.",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _termsAccepted,
                          onChanged: (val) {
                            setState(() {
                              _termsAccepted = val ?? false;
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _termsAccepted = !_termsAccepted;
                            });
                          },
                          child: Text(
                            "J'ai lu et j'accepte les conditions générales d'épargne (frais de gestion et pénalités d'arrêt anticipé).",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textDarkColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isSubmitting || !_termsAccepted) ? null : _handleSubmit,
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
      await widget.onSubmit(double.parse(_amountController.text), _termsAccepted);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception:', '').trim(),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
