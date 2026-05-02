import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_history_entry.dart';

class TontineHistoryList extends StatelessWidget {
  final List<TontineHistoryEntry> history;

  const TontineHistoryList({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(
                Icons.history_toggle_off_rounded,
                size: 44,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                "Aucune operation tontine pour le moment",
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
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
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          leading: CircleAvatar(
            backgroundColor: _typeColor(entry.type).withOpacity(0.12),
            child: Icon(
              _typeIcon(entry.type),
              color: _typeColor(entry.type),
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
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${formatFCFA(entry.amount)} F",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _typeColor(entry.type),
                ),
              ),
              if (entry.note != null)
                Text(
                  entry.note!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  IconData _typeIcon(TontineHistoryType type) {
    switch (type) {
      case TontineHistoryType.configuration:
      case TontineHistoryType.restarted:
        return Icons.tune_rounded;
      case TontineHistoryType.deposit:
        return Icons.add_circle_outline_rounded;
      case TontineHistoryType.cycleCompleted:
        return Icons.flag_circle_rounded;
      case TontineHistoryType.payoutConfirmed:
        return Icons.account_balance_wallet_outlined;
      case TontineHistoryType.earlyStop:
        return Icons.pause_circle_outline_rounded;
    }
  }

  Color _typeColor(TontineHistoryType type) {
    switch (type) {
      case TontineHistoryType.configuration:
      case TontineHistoryType.restarted:
        return AppTheme.primaryColor;
      case TontineHistoryType.deposit:
        return AppTheme.secondaryColor;
      case TontineHistoryType.cycleCompleted:
        return AppTheme.accentColor;
      case TontineHistoryType.payoutConfirmed:
        return const Color(0xFF00897B);
      case TontineHistoryType.earlyStop:
        return AppTheme.errorColor;
    }
  }
}
