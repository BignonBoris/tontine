import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/available_balance_history_entry.dart';

class AvailableBalanceHistoryList extends StatelessWidget {
  final List<AvailableBalanceHistoryEntry> history;
  final ValueChanged<AvailableBalanceHistoryEntry>? onTap;

  const AvailableBalanceHistoryList({
    super.key,
    required this.history,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            "Aucune operation sur le solde disponible.",
            style: GoogleFonts.inter(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: history.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = history[index];
        final color = entry.isCredit
            ? const Color(0xFF00897B)
            : AppTheme.errorColor;

        return ListTile(
          onTap: onTap == null ? null : () => onTap!(entry),
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              entry.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          title: Text(
            entry.label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(entry.date),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          trailing: Text(
            "${entry.isCredit ? '+' : '-'} ${formatFCFA(entry.amount)} F",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
