import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

/// Carte de bienvenue éducative du tableau de bord.
///
/// Affichée une seule fois (préférence persistée côté client), elle présente
/// les 3 espaces clés de l'application au nouvel utilisateur — onboarding
/// progressif conforme aux bonnes pratiques UX (Material Design / NN/g) et à
/// la règle WCAG 3.3.2 « Étiquettes ou instructions ».
class DashboardWelcomeCard extends StatelessWidget {
  final String firstName;
  final VoidCallback onDismiss;

  const DashboardWelcomeCard({
    super.key,
    required this.firstName,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  // Emoji décoratif : masqué aux lecteurs d'écran (règle P7).
                  child: ExcludeSemantics(
                    child: Text('👋', style: TextStyle(fontSize: 17)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue $firstName !',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comprenez vos 3 espaces en quelques secondes :',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppTheme.textSecondaryColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Cible tactile 44x44 + libellé accessible (WCAG 2.5.8 / 4.1.2).
              SizedBox(
                width: 44,
                height: 44,
                child: Tooltip(
                  message: 'Fermer la présentation',
                  child: InkWell(
                    onTap: onDismiss,
                    borderRadius: BorderRadius.circular(22),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildZone(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: AppTheme.secondaryVariantColor,
            title: 'Solde',
            description:
                'Votre argent : disponible au retrait ou engagé en tontine.',
          ),
          const SizedBox(height: 10),
          _buildZone(
            icon: Icons.cached_rounded,
            iconColor: AppTheme.primaryColor,
            title: 'Tontine',
            description: 'Vos cotisations et vos tours avec le groupe.',
          ),
          const SizedBox(height: 10),
          _buildZone(
            icon: Icons.savings_rounded,
            iconColor: AppTheme.accentDarkColor,
            title: 'Coffres',
            description: 'Votre épargne dédiée à chaque projet.',
          ),
        ],
      ),
    );
  }

  Widget _buildZone({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textSecondaryColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
