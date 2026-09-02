import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';

class TontinePaymentMethodTile extends StatelessWidget {
  final String code;
  final String label;
  final String? description;
  final bool isSelected;
  final VoidCallback onTap;
  final double? availableBalance;

  const TontinePaymentMethodTile({
    super.key,
    required this.code,
    required this.label,
    this.description,
    required this.isSelected,
    required this.onTap,
    this.availableBalance,
  });

  @override
  Widget build(BuildContext context) {
    final methodVisuals = _getMethodVisuals(code);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentColor.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.accentColor : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Icône de la méthode
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: methodVisuals.backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: methodVisuals.borderColor,
                  width: 1,
                ),
              ),
              child: Icon(
                methodVisuals.icon,
                color: methodVisuals.iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Textes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppTheme.primaryColor : Colors.black87,
                        ),
                      ),
                      if (methodVisuals.badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: methodVisuals.badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            methodVisuals.badgeText!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: methodVisuals.badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    code == 'wallet' && availableBalance != null
                        ? 'Solde dispo : ${formatFCFA(availableBalance!)} F'
                        : (description ?? methodVisuals.defaultSubtitle),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: code == 'wallet' && isSelected
                          ? AppTheme.accentDarkColor
                          : AppTheme.textSecondaryColor,
                      fontWeight: code == 'wallet' ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Radio indicateur
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  _MethodVisuals _getMethodVisuals(String code) {
    switch (code) {
      case 'wallet':
        return _MethodVisuals(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: AppTheme.primaryColor,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          badgeText: 'Instantané',
          badgeColor: AppTheme.successColor,
          defaultSubtitle: 'Débit direct de votre solde disponible',
        );
      case 'mtn_momo':
        return _MethodVisuals(
          icon: Icons.phone_android_rounded,
          iconColor: const Color(0xFFE6A100),
          backgroundColor: const Color(0xFFFFF9E6),
          borderColor: const Color(0xFFFFE082),
          badgeText: 'MoMo Bénin',
          badgeColor: const Color(0xFFB78103),
          defaultSubtitle: 'Paiement direct sans frais par prompt USSD',
        );
      case 'fedapay':
        return _MethodVisuals(
          icon: Icons.credit_card_rounded,
          iconColor: const Color(0xFF0070BA),
          backgroundColor: const Color(0xFFEBF5FB),
          borderColor: const Color(0xFFBEE3F8),
          badgeText: 'Mobile Money / CB',
          badgeColor: const Color(0xFF0070BA),
          defaultSubtitle: 'MTN, Moov, Celtiis & Carte Visa/Mastercard',
        );
      case 'afrikmoney':
        return _MethodVisuals(
          icon: Icons.hub_rounded,
          iconColor: const Color(0xFF2E7D32),
          backgroundColor: const Color(0xFFE8F5E9),
          borderColor: const Color(0xFFA5D6A7),
          badgeText: 'Sous-région',
          badgeColor: const Color(0xFF2E7D32),
          defaultSubtitle: 'Portefeuille sécurisé UEMOA',
        );
      default:
        return _MethodVisuals(
          icon: Icons.payments_rounded,
          iconColor: AppTheme.primaryColor,
          backgroundColor: Colors.grey.shade100,
          borderColor: Colors.grey.shade200,
          defaultSubtitle: 'Paiement électronique sécurisé',
        );
    }
  }
}

class _MethodVisuals {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final String? badgeText;
  final Color badgeColor;
  final String defaultSubtitle;

  _MethodVisuals({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    this.badgeText,
    this.badgeColor = AppTheme.primaryColor,
    required this.defaultSubtitle,
  });
}
