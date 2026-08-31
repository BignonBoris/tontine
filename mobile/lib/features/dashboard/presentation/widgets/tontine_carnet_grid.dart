import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';

class TontineCarnetGrid extends StatefulWidget {
  final TontineCycle cycle;
  final VoidCallback? onPayNextDayPressed;
  final bool initiallyExpanded;
  final bool isModal;

  const TontineCarnetGrid({
    super.key,
    required this.cycle,
    this.onPayNextDayPressed,
    this.initiallyExpanded = false,
    this.isModal = false,
  });

  @override
  State<TontineCarnetGrid> createState() => _TontineCarnetGridState();
}

class _TontineCarnetGridState extends State<TontineCarnetGrid> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isModal || widget.initiallyExpanded;
  }

  void _toggleExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stake = widget.cycle.stakeAmount;
    final totalDays = (stake > 0 ? (widget.cycle.targetAmount / stake).round() : 31).clamp(1, 62);
    final paidDays = (stake > 0 ? (widget.cycle.cumulativeAmount / stake).floor() : 0).clamp(0, totalDays);
    final currentDayToPay = paidDays < totalDays ? paidDays + 1 : totalDays;

    if (widget.isModal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé de progression pour la modale
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Progression",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    Text(
                      "$paidDays / $totalDays jours",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentDarkColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (totalDays > 0 ? (paidDays / totalDays) : 0.0).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Grille des 31 cases
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalDays,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index + 1;
              final isPaid = dayNumber <= paidDays;
              final isCurrent = dayNumber == currentDayToPay && !isPaid;
              final isLastDay = dayNumber == totalDays;

              return _buildDayCell(
                context: context,
                dayNumber: dayNumber,
                isPaid: isPaid,
                isCurrent: isCurrent,
                isLastDay: isLastDay,
                stakeAmount: stake,
              );
            },
          ),

          const SizedBox(height: 18),

          // Légende ergonomique
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(
                  color: AppTheme.accentColor,
                  icon: Icons.check_rounded,
                  label: 'Cotisé',
                ),
                _buildLegendItem(
                  color: AppTheme.primaryColor,
                  isBorderOnly: true,
                  label: 'En cours',
                ),
                _buildLegendItem(
                  color: Colors.grey.shade400,
                  label: 'À venir',
                ),
                _buildLegendItem(
                  color: const Color(0xFFE65100),
                  icon: Icons.flag_rounded,
                  label: 'Terme',
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête cliquable du carnet
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppTheme.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carnet de pointage',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$paidDays sur $totalDays jours cotisés',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton interactif Masquer / Afficher avec chevron animé
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isExpanded
                        ? AppTheme.primaryColor.withValues(alpha: 0.07)
                        : AppTheme.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isExpanded
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : AppTheme.accentColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Masquer' : 'Afficher',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isExpanded
                              ? AppTheme.primaryColor
                              : AppTheme.accentDarkColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: _isExpanded
                              ? AppTheme.primaryColor
                              : AppTheme.accentDarkColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mini barre de progression quand le carnet est replié
          if (!_isExpanded) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (totalDays > 0 ? (paidDays / totalDays) : 0.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFFF1F4F8),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
              ),
            ),
          ],

          // Contenu déroulant avec transition fluide
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),

                // Grille des 31 cases
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalDays,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final dayNumber = index + 1;
                    final isPaid = dayNumber <= paidDays;
                    final isCurrent = dayNumber == currentDayToPay && !isPaid;
                    final isLastDay = dayNumber == totalDays;

                    return _buildDayCell(
                      context: context,
                      dayNumber: dayNumber,
                      isPaid: isPaid,
                      isCurrent: isCurrent,
                      isLastDay: isLastDay,
                      stakeAmount: stake,
                    );
                  },
                ),

                const SizedBox(height: 18),

                // Légende ergonomique
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildLegendItem(
                        color: AppTheme.accentColor,
                        icon: Icons.check_rounded,
                        label: 'Cotisé',
                      ),
                      _buildLegendItem(
                        color: AppTheme.primaryColor,
                        isBorderOnly: true,
                        label: 'En cours',
                      ),
                      _buildLegendItem(
                        color: Colors.grey.shade400,
                        label: 'À venir',
                      ),
                      _buildLegendItem(
                        color: const Color(0xFFE65100),
                        icon: Icons.flag_rounded,
                        label: 'Terme',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell({
    required BuildContext context,
    required int dayNumber,
    required bool isPaid,
    required bool isCurrent,
    required bool isLastDay,
    required double stakeAmount,
  }) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    Widget content;

    if (isPaid) {
      backgroundColor = AppTheme.accentColor.withValues(alpha: 0.14);
      borderColor = AppTheme.accentColor.withValues(alpha: 0.65);
      textColor = AppTheme.accentDarkColor;
      content = Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$dayNumber',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.35),
            ),
          ),
          const Icon(
            Icons.check_rounded,
            color: AppTheme.accentDarkColor,
            size: 16,
          ),
        ],
      );
    } else if (isCurrent) {
      backgroundColor = AppTheme.primaryColor.withValues(alpha: 0.08);
      borderColor = AppTheme.primaryColor;
      textColor = AppTheme.primaryColor;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$dayNumber',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppTheme.accentColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      );
    } else {
      backgroundColor = const Color(0xFFF7F8FA);
      borderColor = Colors.grey.shade200;
      textColor = Colors.grey.shade500;
      content = Text(
        '$dayNumber',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      );
    }

    if (isLastDay && !isPaid) {
      borderColor = const Color(0xFFFFB74D);
      backgroundColor = const Color(0xFFFFF8E1);
      textColor = const Color(0xFFE65100);
      content = Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$dayNumber',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: textColor.withValues(alpha: 0.4),
            ),
          ),
          const Icon(
            Icons.flag_rounded,
            color: Color(0xFFE65100),
            size: 14,
          ),
        ],
      );
    }

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _showDayInfoDialog(
          context: context,
          dayNumber: dayNumber,
          isPaid: isPaid,
          isCurrent: isCurrent,
          isLastDay: isLastDay,
          stakeAmount: stakeAmount,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isCurrent ? 1.8 : 1.0,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: content,
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    IconData? icon,
    bool isBorderOnly = false,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isBorderOnly ? Colors.transparent : color.withValues(alpha: icon != null ? 0.25 : 0.6),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: color,
              width: 1.2,
            ),
          ),
          child: icon != null
              ? Icon(icon, size: 10, color: color)
              : null,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  void _showDayInfoDialog({
    required BuildContext context,
    required int dayNumber,
    required bool isPaid,
    required bool isCurrent,
    required bool isLastDay,
    required double stakeAmount,
  }) {
    String title = 'Jour $dayNumber / 31';
    String message;
    IconData icon;
    Color iconColor;

    if (isPaid) {
      icon = Icons.verified_rounded;
      iconColor = AppTheme.successColor;
      message = 'Cotisation de ${formatFCFA(stakeAmount)} F enregistrée et validée.';
    } else if (isCurrent) {
      icon = Icons.pending_actions_rounded;
      iconColor = AppTheme.accentColor;
      message = 'Cotisation en cours. Montant de la mise : ${formatFCFA(stakeAmount)} F.';
    } else if (isLastDay) {
      icon = Icons.emoji_events_rounded;
      iconColor = const Color(0xFFE65100);
      message = 'Dernier jour du cycle ! Le 31e jour clôture votre tontine et débloque votre reversement net.';
    } else {
      icon = Icons.schedule_rounded;
      iconColor = Colors.grey;
      message = 'Cotisation à venir (${formatFCFA(stakeAmount)} F).';
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondaryColor,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Fermer',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          if (isCurrent && widget.onPayNextDayPressed != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                widget.onPayNextDayPressed!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cotiser maintenant'),
            ),
        ],
      ),
    );
  }
}
