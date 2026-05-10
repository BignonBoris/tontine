import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/home/data/services/agent_dashboard_service.dart';
import 'package:agent/features/home/domain/entities/agent_overview.dart';
import 'package:agent/features/home/presentation/widgets/agent_overview_tile.dart';
import 'package:agent/features/home/presentation/widgets/agent_quick_action_card.dart';
import 'package:agent/features/withdrawals/presentation/widgets/agent_withdrawal_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgentHomeScreen extends StatefulWidget {
  final VoidCallback onOpenClients;
  final VoidCallback onOpenProvisioning;
  final VoidCallback onOpenHistory;

  const AgentHomeScreen({
    super.key,
    required this.onOpenClients,
    required this.onOpenProvisioning,
    required this.onOpenHistory,
  });

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final _service = AgentDashboardService();
  late Future<AgentOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _service.fetchOverview();
  }

  void _reload() {
    setState(() {
      _overviewFuture = _service.fetchOverview();
    });
  }

  Future<void> _openWithdrawalPaymentSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentWithdrawalPaymentSheet(),
    );

    if (!mounted || result != true) {
      return;
    }

    _reload();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Retrait client paye avec succes.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('VizioBox Agent'),
        actions: [
          IconButton(
            onPressed: widget.onOpenHistory,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const AgentLogoutAction(),
        ],
      ),
      body: FutureBuilder<AgentOverview>(
        future: _overviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AgentLoadingView(
              message: 'Chargement du tableau de bord agent...',
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiException
                ? error.message
                : "Impossible de charger les donnees agent.";
            return AgentErrorView(
              title: 'Tableau de bord indisponible',
              message: message,
              onRetry: _reload,
            );
          }

          final overview =
              snapshot.data ??
              const AgentOverview(
                agentBalance: 0,
                operationsToday: 0,
                pendingCount: 0,
                totalAmountToday: 0,
                myClientsCount: 0,
                commissionBalance: 0,
                commissionPayableBalance: 0,
              );

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A237E), Color(0xFF3144B8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour Agent',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Pilotez les operations de terrain.",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            AgentOverviewTile(
                              label: 'Mes clients',
                              value: '${overview.myClientsCount}',
                              onTap: widget.onOpenClients,
                            ),
                            const SizedBox(width: 14),
                            AgentOverviewTile(
                              label: 'Caisse disponible',
                              value: formatFcfa(overview.agentBalance),
                              onTap: widget.onOpenProvisioning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            AgentOverviewTile(
                              label: 'Commissions gagnees',
                              value: formatFcfa(overview.commissionBalance),
                            ),
                            const SizedBox(width: 14),
                            AgentOverviewTile(
                              label: 'Operations en attente',
                              value: '${overview.pendingCount}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(
                    title: 'Actions rapides',
                    subtitle:
                        "Les operations les plus frequentes sur le terrain.",
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.12,
                    children: [
                      AgentQuickActionCard(
                        icon: Icons.people_alt_outlined,
                        title: 'Mes clients',
                        subtitle: 'Consulter le portefeuille client',
                        tint: AgentAppTheme.primaryColor,
                        onTap: widget.onOpenClients,
                      ),
                      AgentQuickActionCard(
                        icon: Icons.add_card_rounded,
                        title: 'Nouveau depot',
                        subtitle: 'Debiter la caisse pour crediter un client',
                        tint: AgentAppTheme.secondaryColor,
                        onTap: widget.onOpenProvisioning,
                      ),
                      AgentQuickActionCard(
                        icon: Icons.receipt_long_outlined,
                        title: 'Historique du jour',
                        subtitle: 'Verifier les operations recentes',
                        tint: AgentAppTheme.accentColor,
                        onTap: widget.onOpenHistory,
                      ),
                      AgentQuickActionCard(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Caisse admin',
                        subtitle: "L'approvisionnement de caisse se fait desormais via l'administration",
                        tint: const Color(0xFF6B7280),
                        onTap: () {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "L'approvisionnement de caisse est reserve a l'administration.",
                                ),
                              ),
                            );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SectionTitle(
                    title: 'Suivi de caisse',
                    subtitle:
                        'Collecte du jour: ${formatFcfa(overview.totalAmountToday)}. Les depots sont bloques si la caisse agent est insuffisante.',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Retrait client',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AgentAppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Le client vous communique une reference puis un code de confirmation pour finaliser le paiement.",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.4,
                            color: AgentAppTheme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openWithdrawalPaymentSheet,
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Payer un retrait'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AgentInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AgentInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AgentAppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.4,
              color: AgentAppTheme.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
