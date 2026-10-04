import 'dart:async';
import 'package:intl/intl.dart';

import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/security/privacy_provider.dart';
import 'package:agent/core/services/realtime_notification_service.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/utils/mask_utils.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/home/domain/entities/agent_overview.dart';
import 'package:agent/features/home/data/services/agent_dashboard_service.dart';
import 'package:agent/features/home/domain/entities/agent_overview.dart';
import 'package:agent/features/home/presentation/widgets/agent_overview_tile.dart';
import 'package:agent/features/home/presentation/widgets/agent_quick_action_card.dart';
import 'package:agent/features/provisioning/domain/entities/agent_provisioning.dart';
import 'package:agent/features/provisioning/presentation/widgets/agent_provisioning_list_tile.dart';
import 'package:agent/features/notifications/presentation/screens/agent_notifications_screen.dart';
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

class _AgentHomeScreenState extends State<AgentHomeScreen>
    with SingleTickerProviderStateMixin {
  final _service = AgentDashboardService();
  final _realtimeService = RealtimeNotificationService();
  StreamSubscription<RealtimeNotificationEvent>? _realtimeSubscription;
  Timer? _realtimeRefreshTimer;
  bool _disposed = false;
  late Future<AgentOverview> _overviewFuture;
  late AnimationController _heroAnimController;
  late Animation<double> _heroFadeAnim;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _service.fetchOverview();
    _ensureRealtimeSubscription();

    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _heroFadeAnim = CurvedAnimation(
      parent: _heroAnimController,
      curve: Curves.easeOut,
    );
    _heroAnimController.forward();
  }

  void _reload() {
    setState(() {
      _overviewFuture = _service.fetchOverview();
    });
    _heroAnimController.forward(from: 0);
  }

  Future<void> _openNotificationsCenter() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgentNotificationsScreen()),
    );

    if (!mounted) {
      return;
    }

    _reload();
  }

  void _ensureRealtimeSubscription() {
    if (_realtimeSubscription != null) {
      return;
    }

    _realtimeSubscription = _realtimeService.stream.listen((event) {
      if (_disposed) {
        return;
      }

      if (event.eventName == 'notification.created') {
        _scheduleRealtimeRefresh();
      }
    });
  }

  void _scheduleRealtimeRefresh() {
    if (_disposed) {
      return;
    }

    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(const Duration(milliseconds: 500), () {
      if (_disposed || !mounted) {
        return;
      }
      _reload();
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
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Retrait client payé avec succès.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: AgentAppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _disposed = true;
    _heroAnimController.dispose();
    _realtimeRefreshTimer?.cancel();
    unawaited(_realtimeSubscription?.cancel());
    unawaited(_realtimeService.dispose());
    super.dispose();
  }

  /// Retourne "Bonjour", "Bon après-midi" ou "Bonsoir" selon l'heure.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AgentAppTheme.backgroundColor,
      appBar: _buildAppBar(),
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
                : "Impossible de charger les données agent.";
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
                unreadNotificationsCount: 0,
              );

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AgentAppTheme.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: FadeTransition(
                opacity: _heroFadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(overview),
                    const SizedBox(height: 16),
                    _buildLastOperationBanner(overview),
                    const SizedBox(height: 24),
                    const SectionTitle(
                      title: 'Actions rapides',
                      subtitle:
                          'Les opérations les plus fréquentes sur le terrain.',
                    ),
                    const SizedBox(height: 14),
                    _buildQuickActions(overview),

                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AgentAppTheme.primaryColor,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(AgentAppTheme.brandIconAsset),
          ),
          const SizedBox(width: 10),
          Text(
            'VizioBox Agent',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        FutureBuilder<AgentOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            final unreadCount = snapshot.data?.unreadNotificationsCount ?? 0;

            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _openNotificationsCenter,
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AgentAppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────── HERO CARD ──────────────────────────────────────

  Widget _buildHeroCard(AgentOverview overview) {
    return Builder(
      builder: (context) {
        final isPrivate = PrivacyProvider.of(context).isPrivate;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                AgentAppTheme.primaryColor,
                Color(0xFF0F3060),
                Color(0xFF193A72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AgentAppTheme.primaryColor.withValues(alpha: 0.22),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête : salutation + avatar ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white60,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Agent VizioBox',
                          style: GoogleFonts.poppins(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PrivacyToggleButton(
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── KPI principal : Caisse disponible ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Caisse disponible',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white60,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPrivate
                        ? MaskUtils.maskBalance(
                            formatFcfa(overview.agentBalance),
                          )
                        : formatFcfa(overview.agentBalance),
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),

              // const SizedBox(height: 20),

              // // ── KPIs secondaires : 3 stats ──
              // IntrinsicHeight(
              //   child: Row(
              //     children: [
              //       AgentOverviewTile(
              //         label: 'Mes clients',
              //         value: '${overview.myClientsCount}',
              //         icon: Icons.people_alt_outlined,
              //         onTap: widget.onOpenClients,
              //       ),
              //       const AgentOverviewTileDivider(),
              //       AgentOverviewTile(
              //         label: 'En attente',
              //         value: '${overview.pendingCount}',
              //         icon: Icons.pending_actions_outlined,
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────── BANDEAU DU JOUR ────────────────────────────────

  Widget _buildLastOperationBanner(AgentOverview overview) {
    return Builder(
      builder: (context) {
        final isPrivate = PrivacyProvider.of(context).isPrivate;
        final hasLastOperation = overview.lastOperation != null;
        
        AgentProvisioning? provisioning;
        if (hasLastOperation) {
          provisioning = AgentProvisioning(
            id: overview.lastOperation!['id']?.toString() ?? '',
            reference: overview.lastOperation!['reference']?.toString() ?? '',
            amount: double.tryParse(overview.lastOperation!['amount']?.toString() ?? '0') ?? 0,
            status: overview.lastOperation!['status']?.toString() ?? 'validated',
            createdAt: DateTime.tryParse(overview.lastOperation!['createdAt']?.toString() ?? ''),
            client: AgentProvisioningClient(
              id: '', 
              displayName: overview.lastOperation!['clientName']?.toString() ?? 'Client inconnu',
              phoneNumber: '',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: SectionTitle(
                    title: 'Dernière opération',
                    subtitle: '',
                  ),
                ),
                TextButton(
                  onPressed: widget.onOpenHistory,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Tout l'historique",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AgentAppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_outward_rounded,
                        size: 14,
                        color: AgentAppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasLastOperation && provisioning != null)
              AgentProvisioningListTile(provisioning: provisioning)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                  boxShadow: [
                    BoxShadow(
                      color: AgentAppTheme.primaryColor.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AgentAppTheme.borderColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.hourglass_empty_rounded,
                        color: AgentAppTheme.textSecondaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Aucune opération",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AgentAppTheme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Vous n'avez pas encore effectué d'opération.",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AgentAppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ─────────────────────────── ACTIONS RAPIDES ────────────────────────────────

  Widget _buildQuickActions(AgentOverview overview) {
    return GridView.count(
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
          title: 'Nouveau dépôt',
          subtitle: 'Débiter la caisse pour créditer un client',
          tint: AgentAppTheme.secondaryColor,
          onTap: widget.onOpenProvisioning,
        ),
        AgentQuickActionCard(
          icon: Icons.receipt_long_outlined,
          title: 'Mon historique',
          subtitle: 'Vérifier les opérations récentes',
          tint: AgentAppTheme.accentColor,
          onTap: widget.onOpenHistory,
        ),
        AgentQuickActionCard(
          icon: Icons.payments_outlined,
          title: 'Retrait client',
          subtitle: 'Payer un retrait par référence et code client',
          tint: const Color(0xFF7C3AED),
          badgeCount: overview.pendingCount,
          onTap: _openWithdrawalPaymentSheet,
        ),
      ],
    );
  }


}

// ── Classe inutilisée conservée pour rétrocompatibilité éventuelle ──
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
