import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';

class TontineCycleListItem extends StatelessWidget {
  final TontineCycle? cycle;
  final VoidCallback onTap;
  final VoidCallback onRestartPressed;

  const TontineCycleListItem({
    super.key,
    required this.cycle,
    required this.onTap,
    required this.onRestartPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (cycle == null || !cycle!.isActive) {
      return _TontineEmptyListItem(onRestartPressed: onRestartPressed);
    }

    final activeCycle = cycle!;
    final daysCount = activeCycle.stakeAmount > 0
        ? (activeCycle.cumulativeAmount / activeCycle.stakeAmount)
            .round()
            .clamp(0, 31)
        : 0;
    final progressPercent = (activeCycle.progress * 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rangée 1 : En-tête avec Icône + Titre & Compteur Visuel Direct (Jour X / 31)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.cached_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Tontine Active",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.secondaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Mise : ${formatFCFA(activeCycle.stakeAmount)} F / jour",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Compteur Visuel Direct Badge (Jour 18 / 31)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.40),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12.5,
                            color: AppTheme.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Jour $daysCount / 31",
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Rangée 2 : Barre de Progression bicolore & Pourcentage
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 8,
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: activeCycle.progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.secondaryColor,
                                    AppTheme.accentColor,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "$progressPercent%",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Rangée 3 : Métriques Financières (Épargné vs Gain Net Fin de Cycle)
                Row(
                  children: [
                    Expanded(
                      child: _MetricColumn(
                        label: "Épargné à ce jour",
                        value: "${formatFCFA(activeCycle.cumulativeAmount)} F",
                        valueColor: AppTheme.primaryColor,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MetricColumn(
                        label: "Gain net fin de cycle (J30)",
                        value: "${formatFCFA(activeCycle.netPayoutAmount)} F",
                        valueColor: AppTheme.accentDarkColor,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Séparateur fin
                Divider(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  height: 1,
                ),
                const SizedBox(height: 10),

                // Rangée 4 : Statut du Jour & Accès au Calendrier
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Cotisation du jour à jour",
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Voir calendrier",
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TontineEmptyListItem extends StatelessWidget {
  final VoidCallback onRestartPressed;

  const _TontineEmptyListItem({required this.onRestartPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.savings_rounded,
            color: AppTheme.accentDarkColor,
            size: 22,
          ),
        ),
        title: Text(
          "Aucune tontine active",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.primaryColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Configurez votre mise pour démarrer un tour.",
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryColor,
              fontSize: 12.5,
            ),
          ),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: onRestartPressed,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            tooltip: "Démarrer une tontine",
          ),
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final CrossAxisAlignment crossAxisAlignment;
  final TextAlign textAlign;

  const _MetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: textAlign,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
