import 'package:flutter/material.dart';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_clock_outlined,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Tontine active",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Mise ${formatFCFA(activeCycle.stakeAmount)} F",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${(activeCycle.progress * 100).toInt()}%",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: activeCycle.progress,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.secondaryColor,
                  ),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricColumn(
                      label: "Cumul actuel",
                      value: "${formatFCFA(activeCycle.cumulativeAmount)} F",
                      valueColor: AppTheme.primaryColor,
                    ),
                  ),
                  Expanded(
                    child: _MetricColumn(
                      label: "Objectif cycle",
                      value: "${formatFCFA(activeCycle.targetAmount)} F",
                      valueColor: AppTheme.accentColor,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.savings_outlined,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          "Aucune tontine active",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppTheme.primaryColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            "Commencez une nouvelle tontine.",
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryColor,
              fontSize: 13,
            ),
          ),
        ),
        trailing: IconButton(
          onPressed: onRestartPressed,
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryColor),
          tooltip: "Recommencer",
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
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: textAlign,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
