import 'package:flutter/material.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import '../../../../core/theme/app_theme.dart';

class BalanceCardWidget extends StatelessWidget {
  final double availableBalance;
  final double tontineBalance;
  final VoidCallback? onAvailableTap;

  const BalanceCardWidget({
    super.key,
    required this.availableBalance,
    required this.tontineBalance,
    this.onAvailableTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              "Solde Total Estimé",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              "${formatFCFA(availableBalance + tontineBalance)} FCFA",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSubBalance(
                  "Disponible",
                  availableBalance,
                  AppTheme.secondaryColor,
                  Icons.lock_open_rounded,
                  onTap: onAvailableTap,
                ),
                Container(width: 1, height: 30, color: Colors.white12),
                _buildSubBalance(
                  "En Tontine",
                  tontineBalance,
                  AppTheme.accentColor,
                  Icons.lock_outline_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubBalance(
    String label,
    double amount,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.white60),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          formatFCFA(amount.toInt()),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
    );
  }
}
