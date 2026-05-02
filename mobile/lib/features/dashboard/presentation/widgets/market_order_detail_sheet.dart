import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/market_order.dart';
import 'package:mobile/features/dashboard/presentation/widgets/market_order_status_badge.dart';

class MarketOrderDetailSheet extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback? onAdvance;
  final VoidCallback? onCancel;

  const MarketOrderDetailSheet({
    super.key,
    required this.order,
    this.onAdvance,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Detail commande",
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FE),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${order.title} x${order.quantity}",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MarketOrderStatusBadge(status: order.status),
                      const SizedBox(height: 14),
                      _InfoRow(
                        label: "Montant",
                        value: "${formatFCFA(order.amount)} F",
                      ),
                      _InfoRow(label: "Quantite", value: "${order.quantity}"),
                      _InfoRow(
                        label: "Prix unitaire",
                        value: "${formatFCFA(order.unitPrice)} F",
                      ),
                      _InfoRow(
                        label: "Creee le",
                        value: DateFormat(
                          'dd/MM/yyyy a HH:mm',
                          'fr_FR',
                        ).format(order.date),
                      ),
                      _InfoRow(
                        label: "Mise a jour",
                        value: order.updatedAt == null
                            ? "Aucune"
                            : DateFormat(
                                'dd/MM/yyyy a HH:mm',
                                'fr_FR',
                              ).format(order.updatedAt!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _statusDescription(order.status),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                if (order.status.canAdvance)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onAdvance,
                      child: Text(order.status.nextActionLabel),
                    ),
                  ),
                if (order.status.canAdvance && order.status.canCancel)
                  const SizedBox(height: 10),
                if (order.status.canCancel)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      child: const Text("Annuler et rembourser"),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusDescription(MarketOrderStatus status) {
    switch (status) {
      case MarketOrderStatus.pending:
        return "La commande a ete enregistree et attend sa confirmation.";
      case MarketOrderStatus.confirmed:
        return "La commande est confirmee et en cours de preparation.";
      case MarketOrderStatus.ready:
        return "La commande est prete. Vous pouvez la marquer comme livree.";
      case MarketOrderStatus.completed:
        return "La commande est finalisee avec succes.";
      case MarketOrderStatus.cancelled:
        return "La commande a ete annulee. Le remboursement a ete renvoye au solde disponible.";
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
