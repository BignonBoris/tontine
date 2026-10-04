import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/provisioning/domain/entities/agent_provisioning.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AgentProvisioningListTile extends StatelessWidget {
  final AgentProvisioning provisioning;

  const AgentProvisioningListTile({
    super.key,
    required this.provisioning,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = provisioning.createdAt ?? provisioning.validatedAt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AgentAppTheme.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AgentAppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AgentAppTheme.secondaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  createdAt != null ? DateFormat('dd MMM', 'fr_FR').format(createdAt) : '-',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AgentAppTheme.secondaryColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  createdAt != null ? DateFormat('HH:mm', 'fr_FR').format(createdAt) : '-',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AgentAppTheme.secondaryColor.withValues(alpha: 0.7),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provisioning.client?.displayName ?? 'Client inconnu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AgentAppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusBadge(status: provisioning.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  provisioning.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AgentAppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatFcfa(provisioning.amount),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AgentAppTheme.primaryColor,
                  ),
                ),
                if (provisioning.notes != null &&
                    provisioning.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    provisioning.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AgentAppTheme.textSecondaryColor,
                      height: 1.35,
                    ),
                  ),
                ],
                if (provisioning.reversalReason != null &&
                    provisioning.reversalReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Motif: ${provisioning.reversalReason!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AgentAppTheme.errorColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'validated' => AgentAppTheme.secondaryColor,
      'pending_validation' => AgentAppTheme.accentColor,
      'rejected' || 'cancelled' => AgentAppTheme.errorColor,
      _ => AgentAppTheme.primaryColor,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(status),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _label(String value) {
    return switch (value) {
      'validated' => 'Valide',
      'pending_validation' => 'En attente',
      'rejected' => 'Rejete',
      'cancelled' => 'Annule',
      _ => 'Initie',
    };
  }
}
