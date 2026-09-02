import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class QuickActionsBar extends StatelessWidget {
  final VoidCallback onDepositPressed;
  final VoidCallback onWithdrawPressed;
  final VoidCallback onQrPressed;
  final VoidCallback? onHistoryPressed;

  const QuickActionsBar({
    super.key,
    required this.onDepositPressed,
    required this.onWithdrawPressed,
    required this.onQrPressed,
    this.onHistoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Cotiser (Action Primaire Dorée)
        // Décision design (charte VizioBox) : le texte des CTA dorés reste BLANC.
        _buildActionChip(
          label: 'Cotiser',
          icon: Icons.savings_rounded,
          gradient: AppTheme.accentGradient,
          iconColor: Colors.white,
          textColor: Colors.white,
          isPrimary: true,
          onTap: onDepositPressed,
        ),
        const SizedBox(width: 8),

        // 2. Retirer (Action Secondaire Émeraude / Retirable)
        _buildActionChip(
          label: 'Retirer',
          icon: Icons.payments_outlined,
          backgroundColor: Colors.white,
          borderColor: AppTheme.secondaryColor.withValues(alpha: 0.35),
          iconColor: AppTheme.secondaryColor,
          textColor: AppTheme.primaryColor,
          onTap: onWithdrawPressed,
        ),
        const SizedBox(width: 8),

        // 3. Mon QR (Action d'identification KYC)
        _buildActionChip(
          label: 'Mon QR',
          icon: Icons.qr_code_2_rounded,
          backgroundColor: Colors.white,
          borderColor: AppTheme.primaryColor.withValues(alpha: 0.15),
          iconColor: AppTheme.primaryColor,
          textColor: AppTheme.primaryColor,
          onTap: onQrPressed,
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    Gradient? gradient,
    Color? backgroundColor,
    Color? borderColor,
    required Color iconColor,
    required Color textColor,
    bool isPrimary = false,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? backgroundColor : null,
              borderRadius: BorderRadius.circular(14),
              border: borderColor != null
                  ? Border.all(color: borderColor, width: 1.2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isPrimary
                          ? AppTheme.accentDarkColor
                          : AppTheme.primaryColor)
                      .withValues(alpha: isPrimary ? 0.22 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.22)
                        : iconColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
