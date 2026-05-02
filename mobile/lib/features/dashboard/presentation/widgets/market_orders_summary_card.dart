import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/market_order.dart';

class MarketOrdersSummaryCard extends StatelessWidget {
  final List<MarketOrder> orders;

  const MarketOrdersSummaryCard({
    super.key,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: orders.isEmpty
          ? Text(
              "Aucun achat pour le moment.",
              style: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
            )
          : Column(
              children: orders.map((order) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.secondaryColor.withOpacity(0.12),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  title: Text(
                    order.title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    "Statut: en attente",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  trailing: Text(
                    "${formatFCFA(order.amount)} F",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
