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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('maTontine Agent'),
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
                operationsToday: 0,
                pendingCount: 0,
                totalAmountToday: 0,
                myClientsCount: 0,
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
                              label: 'Montant collecte',
                              value: formatFcfa(overview.totalAmountToday),
                              onTap: widget.onOpenProvisioning,
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
                        subtitle: 'Initier un provisioning terrain',
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
                        icon: Icons.sync_rounded,
                        title: 'Synchronisation',
                        subtitle: 'Actualiser les donnees du terrain',
                        tint: const Color(0xFF6B7280),
                        onTap: _reload,
                      ),
                    ],
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
