import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_archive_entry.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_cycle.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_history_entry.dart';
import 'package:mobile/features/dashboard/domain/entities/payment_method_option.dart';
import 'package:mobile/features/dashboard/data/services/tontine_afrikmoney_service.dart';
import 'package:mobile/features/dashboard/data/services/tontine_fedapay_service.dart';
import 'package:mobile/features/dashboard/data/services/tontine_mtn_momo_service.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/configure_tontine_stake_modal.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_action_button.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_carnet_grid.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_history_list.dart';
import 'package:mobile/features/groups/presentation/widgets/my_groups_section.dart';
import 'package:mobile/features/groups/presentation/widgets/unified_adhesions_section.dart';
import 'package:url_launcher/url_launcher.dart';

class TontineDetailScreen extends StatefulWidget {
  final bool showBackButton;

  const TontineDetailScreen({super.key, this.showBackButton = true});

  @override
  State<TontineDetailScreen> createState() => _TontineDetailScreenState();
}

class _TontineDetailScreenState extends State<TontineDetailScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _pendingInvitationCount = 0;
  int _pendingRequestCount = 0;
  late final TabController _tabController;
  bool _refreshOnResumeAfterFedapay = false;
  bool _refreshOnResumeAfterAfrikmoney = false;
  bool _refreshOnResumeAfterMtnMomo = false;
  String? _pendingFedapayIntentId;
  String? _pendingAfrikmoneyIntentId;
  String? _pendingMtnMomoIntentId;
  bool _isMonitoringMtnMomoIntent = false;

  void _handleInvitationCountChanged(int count) {
    if (_pendingInvitationCount == count) {
      return;
    }
    setState(() {
      _pendingInvitationCount = count;
    });
  }

  void _handleRequestCountChanged(int count) {
    if (_pendingRequestCount == count) {
      return;
    }
    setState(() {
      _pendingRequestCount = count;
    });
  }

  int get _adhesionPendingCount =>
      _pendingInvitationCount + _pendingRequestCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    if (_refreshOnResumeAfterFedapay) {
      _refreshOnResumeAfterFedapay = false;
      unawaited(_refreshFedapayDepositAfterResume());
      return;
    }

    if (_refreshOnResumeAfterAfrikmoney) {
      _refreshOnResumeAfterAfrikmoney = false;
      unawaited(_refreshAfrikmoneyDepositAfterResume());
      return;
    }

    if (_refreshOnResumeAfterMtnMomo) {
      _refreshOnResumeAfterMtnMomo = false;
      unawaited(_refreshMtnMomoDepositAfterResume());
    }
  }

  Future<void> _refreshFedapayDepositAfterResume() async {
    final intentId = _pendingFedapayIntentId?.trim();
    if (intentId == null || intentId.isEmpty) {
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardData());
      }
      return;
    }

    final fedapayService = TontineFedapayService();

    for (var attempt = 0; attempt < 6; attempt++) {
      if (!mounted) {
        return;
      }

      try {
        final intent = await fedapayService.fetchDepositIntent(intentId);
        final status = intent.status.toLowerCase();
        final providerStatus = intent.providerStatus?.toLowerCase() ?? '';

        if (status == 'processed' || providerStatus == 'approved') {
          _pendingFedapayIntentId = null;
          await LocalSecurityService.clearTemporaryAppLockBypass();
          if (!mounted) {
            return;
          }

          context.read<DashboardBloc>().add(LoadDashboardData());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paiement FedaPay confirme. Mise a jour en cours.'),
            ),
          );
          return;
        }

        if (status == 'cancelled' ||
            status == 'failed' ||
            status == 'expired') {
          _pendingFedapayIntentId = null;
          await LocalSecurityService.clearTemporaryAppLockBypass();
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le paiement FedaPay a ete annule ou refuse.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        break;
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) {
      return;
    }

    _refreshOnResumeAfterFedapay = true;
    context.read<DashboardBloc>().add(LoadDashboardData());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paiement FedaPay en attente de confirmation.'),
      ),
    );
  }

  Future<void> _refreshAfrikmoneyDepositAfterResume() async {
    final intentId = _pendingAfrikmoneyIntentId?.trim();
    if (intentId == null || intentId.isEmpty) {
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardData());
      }
      return;
    }

    final afrikmoneyService = TontineAfrikmoneyService();

    for (var attempt = 0; attempt < 6; attempt++) {
      if (!mounted) {
        return;
      }

      try {
        final intent = await afrikmoneyService.fetchDepositIntent(intentId);
        final status = intent.status.toLowerCase();
        final providerStatus = intent.providerStatus?.toLowerCase() ?? '';

        if (status == 'processed' ||
            providerStatus == 'success' ||
            providerStatus == 'succeeded' ||
            providerStatus == 'completed' ||
            providerStatus == 'approved') {
          _pendingAfrikmoneyIntentId = null;
          _refreshOnResumeAfterAfrikmoney = false;
          await LocalSecurityService.clearTemporaryAppLockBypass();
          if (!mounted) {
            return;
          }

          context.read<DashboardBloc>().add(LoadDashboardData());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Paiement Afrikmoney confirme. Mise a jour en cours.',
              ),
            ),
          );
          return;
        }

        if (status == 'cancelled' ||
            status == 'failed' ||
            status == 'expired') {
          _pendingAfrikmoneyIntentId = null;
          _refreshOnResumeAfterAfrikmoney = false;
          await LocalSecurityService.clearTemporaryAppLockBypass();
          if (!mounted) {
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le paiement Afrikmoney a ete annule ou refuse.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        break;
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) {
      return;
    }

    _refreshOnResumeAfterAfrikmoney = true;
    context.read<DashboardBloc>().add(LoadDashboardData());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paiement Afrikmoney en attente de confirmation.'),
      ),
    );
  }

  Future<void> _refreshMtnMomoDepositAfterResume() async {
    if (_isMonitoringMtnMomoIntent) {
      return;
    }

    _isMonitoringMtnMomoIntent = true;
    try {
      final intentId = _pendingMtnMomoIntentId?.trim();
      if (intentId == null || intentId.isEmpty) {
        _refreshOnResumeAfterMtnMomo = false;
        if (mounted) {
          context.read<DashboardBloc>().add(LoadDashboardData());
        }
        return;
      }

      final mtnMomoService = TontineMtnMomoService();

      for (var attempt = 0; attempt < 6; attempt++) {
        if (!mounted) {
          return;
        }

        try {
          final intent = await mtnMomoService.fetchDepositIntent(intentId);
          final status = intent.status.toLowerCase();
          final providerStatus = intent.providerStatus?.toLowerCase() ?? '';

          if (status == 'processed' ||
              providerStatus == 'approved' ||
              providerStatus == 'successful') {
            _pendingMtnMomoIntentId = null;
            _refreshOnResumeAfterMtnMomo = false;
            if (!mounted) {
              return;
            }

            context.read<DashboardBloc>().add(LoadDashboardData());
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Paiement MTN MoMo confirme. Mise a jour en cours.',
                ),
              ),
            );
            return;
          }

          if (status == 'cancelled' ||
              status == 'failed' ||
              status == 'expired') {
            _pendingMtnMomoIntentId = null;
            _refreshOnResumeAfterMtnMomo = false;
            if (!mounted) {
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Le paiement MTN MoMo a ete annule ou refuse.',
                ),
              ),
            );
            return;
          }
        } catch (_) {
          break;
        }

        await Future.delayed(const Duration(seconds: 2));
      }

      if (!mounted) {
        return;
      }

      _refreshOnResumeAfterMtnMomo = true;
      context.read<DashboardBloc>().add(LoadDashboardData());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Paiement MTN MoMo en attente de confirmation.',
          ),
        ),
      );
    } finally {
      _isMonitoringMtnMomoIntent = false;
    }
  }

  Future<void> _suspendAppLockForFedapay() {
    return LocalSecurityService.startTemporaryAppLockBypass();
  }

  Future<void> _clearFedapayAppLockBypass() {
    return LocalSecurityService.clearTemporaryAppLockBypass();
  }

  void _handleTabChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardOffline) {
          return DashboardOfflineView(
            title: state.title,
            message: state.message,
            inline: true,
          );
        }

        if (state is DashboardError) {
          return DashboardErrorView(
            title: state.title,
            message: state.message,
            requiresReauthentication: state.requiresReauthentication,
          );
        }

        if (state is! DashboardLoaded) {
          return const DashboardLoadingView(
            label: "Chargement de votre tontine...",
          );
        }

        final cycle = state.tontineCycle;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: Column(
            children: [
              _buildTontineHeader(context, state),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: TabBarView(
                    controller: _tabController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _PersonalTontineTab(
                        cycle: cycle,
                        availableBalance: state.availableBalance,
                        history: state.tontineHistory,
                        buildActionArea: (context, cycle, availableBalance) =>
                            _buildActionArea(context, cycle, availableBalance),
                        onDepositTap: cycle != null
                            ? () => _showDepositSheetWithPaymentMethods(
                                context,
                                cycle,
                                state.availableBalance,
                              )
                            : null,
                        onStopTap: cycle != null
                            ? () => _showEarlyStopDialog(context, cycle)
                            : null,
                        onCarnetTap: cycle != null
                            ? () => _showCarnetModal(
                                context,
                                cycle,
                                state.availableBalance,
                              )
                            : null,
                        onSeeAllTap: () => _showAllHistoryModal(
                          context,
                          state.tontineHistory,
                        ),
                      ),
                      const _GroupTontineTab(),
                      _AdhesionsTontineTab(
                        onInvitationCountChanged: _handleInvitationCountChanged,
                        onRequestCountChanged: _handleRequestCountChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetDragHandle() {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTontineHeader(BuildContext context, DashboardLoaded state) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Cercles d'arrière-plan en filigrane (Charte VizioBox)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -35,
            left: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withValues(alpha: 0.05),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rangée supérieure : Retour (si besoin) + Titre + Actions rapides
              Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 6),
                child: Row(
                  children: [
                    if (widget.showBackButton) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        "Ma Tontine",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (_tabController.index == 0)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showTontineArchives(context, state.tontineArchives);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      )
                    else if (_tabController.index == 2)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pushNamed(context, '/group-scanner');
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Onglets style WhatsApp : pleine largeur, soulignés, défilement fluide
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.accentColor,
                indicatorWeight: 3.5,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.white.withValues(alpha: 0.15),
                dividerHeight: 1,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
                overlayColor: WidgetStateProperty.all(
                  Colors.white.withValues(alpha: 0.08),
                ),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  const Tab(text: 'Personnel'),
                  const Tab(text: 'Groupe'),
                  Tab(
                    child: _CountTabLabel(
                      label: 'Adhésions',
                      count: _adhesionPendingCount,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(
    BuildContext context,
    TontineCycle? cycle,
    double availableBalance,
  ) {
    if (cycle == null || cycle.status == TontineCycleStatus.nonConfiguree) {
      return _TontineInfoPanel(
        title: "Aucune tontine en cours",
        description:
            "Vous n'avez pas encore de cycle de tontine actif. Configurez votre mise quotidienne pour lancer un nouveau cycle.",
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showRestartTontineModal(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            label: Text(
              "Configurer ma tontine",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    if (cycle.status == TontineCycleStatus.enAttenteValidationFin) {
      return _TontineInfoPanel(
        title: "Cycle atteint ! 🎉",
        description:
            "Votre objectif est complété. Confirmez le reversement vers votre solde disponible.",
        child: Column(
          children: [
            _AmountLine(
              label: "Total cumulé",
              value: "${formatFCFA(cycle.cumulativeAmount)} F",
            ),
            _AmountLine(
              label: "Commission plateforme",
              value: "${formatFCFA(cycle.commissionAmount)} F",
            ),
            _AmountLine(
              label: "Montant reversé",
              value: "${formatFCFA(cycle.netPayoutAmount)} F",
              isHighlighted: true,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final authorized = await LocalSecurityService.authorizeIfEnabled(
                    context,
                    title: 'Confirmer le reversement',
                    message:
                        "Entrez votre PIN pour confirmer le reversement vers le solde disponible.",
                  );
                  if (!context.mounted || !authorized) {
                    return;
                  }
                  context.read<DashboardBloc>().add(ConfirmTontineCyclePayout());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                label: Text(
                  "Confirmer le reversement",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (cycle.status != TontineCycleStatus.active) {
      return _TontineInfoPanel(
        title: "Cycle non actif",
        description:
            "Ce cycle n'accepte plus de versement. Reconfigurez une nouvelle mise.",
        child: Column(
          children: [
            _AmountLine(
              label: "Dernier montant net de cycle",
              value: "${formatFCFA(cycle.netPayoutAmount)} F",
              isHighlighted: true,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showRestartTontineModal(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  "Recommencer une tontine",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        TontineActionButton(
          label: "Cotiser",
          icon: Icons.savings_rounded,
          gradient: AppTheme.accentGradient,
          iconColor: Colors.white,
          textColor: Colors.white,
          isPrimary: true,
          onTap: () => _showDepositSheetWithPaymentMethods(
            context,
            cycle,
            availableBalance,
          ),
        ),
        const SizedBox(width: 12),
        TontineActionButton(
          label: "Arrêter le cycle",
          icon: Icons.pause_circle_outline_rounded,
          backgroundColor: Colors.white,
          borderColor: AppTheme.errorColor.withValues(alpha: 0.35),
          iconColor: AppTheme.errorColor,
          textColor: AppTheme.errorColor,
          onTap: () => _showEarlyStopDialog(context, cycle),
        ),
      ],
    );
  }

  void _showCarnetModal(
    BuildContext context,
    TontineCycle cycle,
    double availableBalance,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.50,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetDragHandle(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppTheme.accentDarkColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Carnet de pointage",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                "Cycle 31 jours • ${formatFCFA(cycle.stakeAmount)} F / jour",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded),
                        color: AppTheme.textSecondaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TontineCarnetGrid(
                    cycle: cycle,
                    initiallyExpanded: true,
                    isModal: true,
                    onPayNextDayPressed: () {
                      Navigator.pop(modalCtx);
                      _showDepositSheetWithPaymentMethods(
                        context,
                        cycle,
                        availableBalance,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllHistoryModal(
    BuildContext context,
    List<TontineHistoryEntry> history,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.50,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetContext, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetDragHandle(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppTheme.primaryColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Historique des opérations",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                "${history.length} opération${history.length > 1 ? 's' : ''}",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(Icons.close_rounded),
                        color: AppTheme.textSecondaryColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TontineHistoryList(history: history),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDepositSheetWithPaymentMethods(
    BuildContext context,
    TontineCycle cycle,
    double availableBalance,
  ) async {
    final paymentMethodsService = RemoteDashboardService();
    final fetchedMethods = await paymentMethodsService.fetchPaymentMethods(
      'tontine_deposit',
    );
    final paymentMethods = fetchedMethods
        .where((method) => _isSupportedTontineDepositMethod(method.code))
        .toList();

    if (!context.mounted) {
      return;
    }
    if (paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun moyen de paiement disponible pour le moment.',
          ),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final fedapayService = TontineFedapayService();
    final afrikmoneyService = TontineAfrikmoneyService();
    final mtnMomoService = TontineMtnMomoService();
    String? errorMessage;
    bool isSubmitting = false;
    String selectedMethodCode = paymentMethods.first.code;
    final remaining = (cycle.targetAmount - cycle.cumulativeAmount).clamp(
      0.0,
      double.infinity,
    );

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              PaymentMethodOption selectedMethod = paymentMethods.firstWhere(
                (method) => method.code == selectedMethodCode,
                orElse: () => paymentMethods.first,
              );

              Future<void> submitDeposit() async {
                final amount = double.tryParse(controller.text);
                final remaining =
                    (cycle.targetAmount - cycle.cumulativeAmount).clamp(
                      0.0,
                      double.infinity,
                    );

                if (amount == null || amount <= 0) {
                  setSheetState(() => errorMessage = 'Montant invalide');
                  return;
                }

                if (amount % AppInputRules.financialAmountStep != 0) {
                  setSheetState(
                    () => errorMessage =
                        'Le montant doit etre un multiple de ${AppInputRules.financialAmountStep}',
                  );
                  return;
                }

                if (amount > remaining) {
                  setSheetState(
                    () => errorMessage = "Le montant depasse l'objectif restant",
                  );
                  return;
                }

                if (selectedMethod.code == 'wallet' &&
                    amount > availableBalance) {
                  setSheetState(
                    () => errorMessage = 'Solde disponible insuffisant',
                  );
                  return;
                }

                final authorized =
                    await LocalSecurityService.authorizeIfEnabled(
                      context,
                      title: selectedMethod.code == 'wallet'
                          ? 'Transferer vers la tontine'
                          : 'Payer avec le moyen choisi',
                      message: selectedMethod.code == 'wallet'
                          ? 'Entrez votre PIN pour confirmer ce versement dans votre tontine.'
                          : selectedMethod.code == 'mtn_momo'
                              ? 'Entrez votre PIN pour envoyer la demande MTN MoMo.'
                              : selectedMethod.code == 'afrikmoney'
                                  ? 'Entrez votre PIN pour ouvrir le paiement Afrikmoney.'
                              : 'Entrez votre PIN pour lancer le paiement.',
                );
                if (!context.mounted || !authorized) {
                  return;
                }

                if (selectedMethod.code == 'wallet') {
                  context.read<DashboardBloc>().add(
                    MakeTontineDeposit(amount),
                  );
                  if (modalContext.mounted) {
                    Navigator.pop(modalContext);
                  }
                  return;
                }

                setSheetState(() {
                  isSubmitting = true;
                  errorMessage = null;
                });

                try {
                  if (selectedMethod.code == 'fedapay') {
                    final session = await fedapayService.createDeposit(amount);
                    _pendingFedapayIntentId = session.id;
                    final paymentUrl = session.paymentUrl?.trim() ?? '';
                    final paymentUri = paymentUrl.isEmpty
                        ? null
                        : Uri.tryParse(paymentUrl);

                    if (paymentUri == null ||
                        !(paymentUri.scheme == 'https' ||
                            paymentUri.scheme == 'http')) {
                      _pendingFedapayIntentId = null;
                      if (sheetContext.mounted) {
                        setSheetState(() {
                          isSubmitting = false;
                          errorMessage =
                              'Le lien de paiement est indisponible.';
                        });
                      }
                      return;
                    }

                    await _suspendAppLockForFedapay();
                    _refreshOnResumeAfterFedapay = true;
                    final launched = await launchUrl(
                      paymentUri,
                      mode: LaunchMode.externalApplication,
                    );

                    if (!launched) {
                      _refreshOnResumeAfterFedapay = false;
                      _pendingFedapayIntentId = null;
                      await _clearFedapayAppLockBypass();
                      if (sheetContext.mounted) {
                        setSheetState(() {
                          isSubmitting = false;
                          errorMessage =
                              "Impossible d'ouvrir la page de paiement.";
                        });
                      }
                      return;
                    }

                    if (!context.mounted) {
                      return;
                    }

                    if (modalContext.mounted) {
                      Navigator.pop(modalContext);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Paiement ouvert. Revenez dans l\'application apres validation.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (selectedMethod.code == 'afrikmoney') {
                    final session = await afrikmoneyService.createDeposit(amount);
                    _pendingAfrikmoneyIntentId = session.id;
                    final paymentUrl = session.paymentUrl?.trim() ?? '';
                    final paymentUri = paymentUrl.isEmpty
                        ? null
                        : Uri.tryParse(paymentUrl);

                    if (paymentUri == null ||
                        !(paymentUri.scheme == 'https' ||
                            paymentUri.scheme == 'http')) {
                      _pendingAfrikmoneyIntentId = null;
                      if (sheetContext.mounted) {
                        setSheetState(() {
                          isSubmitting = false;
                          errorMessage =
                              'Le lien de paiement Afrikmoney est indisponible.';
                        });
                      }
                      return;
                    }

                    await _suspendAppLockForFedapay();
                    _refreshOnResumeAfterAfrikmoney = true;
                    final launched = await launchUrl(
                      paymentUri,
                      mode: LaunchMode.externalApplication,
                    );

                    if (!launched) {
                      _refreshOnResumeAfterAfrikmoney = false;
                      _pendingAfrikmoneyIntentId = null;
                      await _clearFedapayAppLockBypass();
                      if (sheetContext.mounted) {
                        setSheetState(() {
                          isSubmitting = false;
                          errorMessage =
                              "Impossible d'ouvrir la page de paiement Afrikmoney.";
                        });
                      }
                      return;
                    }

                    if (!context.mounted) {
                      return;
                    }

                    if (modalContext.mounted) {
                      Navigator.pop(modalContext);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Paiement Afrikmoney ouvert. Revenez dans l\'application apres validation.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (selectedMethod.code == 'mtn_momo') {
                    final session = await mtnMomoService.createDeposit(amount);
                    _pendingMtnMomoIntentId = session.id;
                    _refreshOnResumeAfterMtnMomo = true;

                    if (!context.mounted) {
                      return;
                    }

                    if (modalContext.mounted) {
                      Navigator.pop(modalContext);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Demande MTN MoMo envoyee. Validez la requete sur votre telephone.',
                        ),
                      ),
                    );

                    unawaited(_refreshMtnMomoDepositAfterResume());
                    return;
                  }

                  throw Exception('Methode de paiement non supportee.');
                } catch (error) {
                  _pendingFedapayIntentId = null;
                  _refreshOnResumeAfterFedapay = false;
                  _pendingAfrikmoneyIntentId = null;
                  _refreshOnResumeAfterAfrikmoney = false;
                  _pendingMtnMomoIntentId = null;
                  _refreshOnResumeAfterMtnMomo = false;
                  await _clearFedapayAppLockBypass();
                  if (!sheetContext.mounted) {
                    return;
                  }
                  setSheetState(() {
                    isSubmitting = false;
                    errorMessage = error
                        .toString()
                        .replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
                  });
                }
              }

              return SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 14,
                    bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSheetDragHandle(),
                      Text(
                        'Verser dans la tontine',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisissez le mode de paiement. Le montant doit être un multiple de ${AppInputRules.financialAmountStep} F et ne peut pas dépasser le reste à verser du cycle.',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Mode de paiement',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: paymentMethods
                            .map(
                              (method) => ChoiceChip(
                                label: Text(method.label),
                                selected: selectedMethod.code == method.code,
                                onSelected: (selected) {
                                  if (!selected) {
                                    return;
                                  }
                                  setSheetState(() {
                                    selectedMethodCode = method.code;
                                    selectedMethod = method;
                                    errorMessage = null;
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedMethod.description ??
                            _depositMethodDescription(selectedMethod),
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: AppInputRules.amountFormatters,
                        autofocus: true,
                        onChanged: (_) {
                          if (errorMessage != null) {
                            setSheetState(() => errorMessage = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: selectedMethod.code == 'wallet'
                              ? 'Montant à transférer'
                              : 'Montant à payer',
                          suffixText: 'F CFA',
                          helperText: selectedMethod.code == 'wallet'
                              ? 'Disponible : ${formatFCFA(availableBalance)} F • Reste : ${formatFCFA(remaining.toInt())} F'
                              : 'Paiement externe • Reste à verser : ${formatFCFA(remaining.toInt())} F',
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _InlineSheetError(message: errorMessage!),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submitDeposit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _depositActionLabel(selectedMethod.code),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  bool _isSupportedTontineDepositMethod(String code) {
    return code == 'wallet' ||
        code == 'fedapay' ||
        code == 'afrikmoney' ||
        code == 'mtn_momo';
  }

  String _depositMethodDescription(PaymentMethodOption method) {
    switch (method.code) {
      case 'wallet':
        return 'Transfert interne depuis le solde disponible.';
      case 'fedapay':
        return 'Paiement externe via FedaPay. Vous serez redirige vers la page de paiement.';
      case 'afrikmoney':
        return 'Paiement externe via Afrikmoney. Vous serez redirige vers la page de paiement.';
      case 'mtn_momo':
        return 'Une demande sera envoyee sur votre ligne MTN MoMo. Confirmez la requete sur votre telephone.';
      default:
        return 'Paiement externe via le moyen selectionne.';
    }
  }

  String _depositActionLabel(String code) {
    switch (code) {
      case 'wallet':
        return 'Confirmer le transfert';
      case 'fedapay':
        return 'Ouvrir le paiement';
      case 'afrikmoney':
        return 'Ouvrir Afrikmoney';
      case 'mtn_momo':
        return 'Lancer MTN MoMo';
      default:
        return 'Confirmer';
    }
  }

  void _showEarlyStopDialog(BuildContext context, TontineCycle cycle) {
    final netAmount = (cycle.cumulativeAmount - cycle.commissionAmount).clamp(
      0.0,
      double.infinity,
    );

    bool isAccepted = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.stop_circle_outlined,
                      color: AppTheme.errorColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Arrêter la tontine ?",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cette action interrompt immédiatement votre cycle de 31 jours. Conformément aux règles de la tontine, une mise est retenue en pénalité de rupture.",
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: AppTheme.textSecondaryColor,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          _AmountLine(
                            label: "Cumul actuel cotisé",
                            value: "${formatFCFA(cycle.cumulativeAmount)} F CFA",
                          ),
                          const SizedBox(height: 6),
                          _AmountLine(
                            label: "Pénalité retenue (1 mise)",
                            value: "- ${formatFCFA(cycle.commissionAmount)} F CFA",
                          ),
                          Divider(
                            height: 16,
                            color: AppTheme.primaryColor.withValues(alpha: 0.10),
                          ),
                          _AmountLine(
                            label: "Net reversé sur solde",
                            value: "${formatFCFA(netAmount)} F CFA",
                            isHighlighted: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          isAccepted = !isAccepted;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: isAccepted,
                                activeColor: AppTheme.errorColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (val) {
                                  setDialogState(() {
                                    isAccepted = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "J'ai bien compris que cet arrêt est irréversible et j'accepte la retenue de ${formatFCFA(cycle.commissionAmount)} F.",
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimaryColor,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    "Annuler",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isAccepted
                      ? () async {
                          final authorized =
                              await LocalSecurityService.authorizeIfEnabled(
                            context,
                            title: 'Arrêter la tontine',
                            message:
                                "Entrez votre PIN pour confirmer l'arrêt anticipé de cette tontine.",
                          );
                          if (!context.mounted || !authorized) {
                            return;
                          }
                          context.read<DashboardBloc>().add(StopTontineEarly());
                          Navigator.pop(dialogContext);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    disabledBackgroundColor:
                        AppTheme.errorColor.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    "Confirmer l'arrêt",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showRestartTontineModal(BuildContext context) async {
    final dashState = context.read<DashboardBloc>().state;
    final kycStatus = dashState is DashboardLoaded
        ? dashState.profile.kyc.status
        : 'unverified';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return ConfigureTontineStakeModal(
          kycStatus: kycStatus,
          onSubmit: (amount) async {
            context.read<DashboardBloc>().add(ConfigureTontineStake(amount));
          },
        );
      },
    );
  }

  void _showTontineArchives(
    BuildContext context,
    List<TontineArchiveEntry> archives,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetDragHandle(),
              Text(
                "Tontines précédentes",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              if (archives.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "Aucune tontine précédente.",
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: archives.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final archive = archives[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          "Objectif ${formatFCFA(archive.targetAmount)} F",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        subtitle: Text(
                          "Début ${DateFormat('dd/MM/yyyy').format(archive.startDate)} • Fin ${DateFormat('dd/MM/yyyy').format(archive.endDate)}",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textSecondaryColor,
                        ),
                        onTap: () {
                          Navigator.pop(modalContext);
                          _showArchiveSummary(context, archive);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showArchiveSummary(BuildContext context, TontineArchiveEntry archive) {
    final statusLabel = archive.status == TontineArchiveStatus.completed
        ? "Cycle terminé"
        : "Arrêt anticipé";

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            statusLabel,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountLine(
                label: "Date de début",
                value: DateFormat('dd/MM/yyyy').format(archive.startDate),
              ),
              _AmountLine(
                label: "Date de fin",
                value: DateFormat('dd/MM/yyyy').format(archive.endDate),
              ),
              _AmountLine(
                label: "Objectif cycle",
                value: "${formatFCFA(archive.targetAmount)} F",
              ),
              _AmountLine(
                label: "Total cumulé",
                value: "${formatFCFA(archive.cumulativeAmount)} F",
              ),
              _AmountLine(
                label: "Commission",
                value: "${formatFCFA(archive.commissionAmount)} F",
              ),
              _AmountLine(
                label: "Montant reversé",
                value: "${formatFCFA(archive.netPayoutAmount)} F",
                isHighlighted: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Fermer",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TontineHeroCard extends StatelessWidget {
  final TontineCycle? cycle;
  final VoidCallback? onDepositTap;
  final VoidCallback? onStopTap;
  final VoidCallback? onCarnetTap;

  const _TontineHeroCard({
    required this.cycle,
    this.onDepositTap,
    this.onStopTap,
    this.onCarnetTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cycle == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aucune tontine active",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Reconfigurez une mise pour relancer un cycle.",
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final stake = cycle!.stakeAmount;
    final totalDays = (stake > 0 ? (cycle!.targetAmount / stake).round() : 31).clamp(1, 62);
    final paidDays = (stake > 0 ? (cycle!.cumulativeAmount / stake).floor() : 0).clamp(0, totalDays);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Montant à gauche + Boutons d'action compacts à droite (icônes uniquement)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL COTISÉ",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondaryColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatFCFA(cycle!.cumulativeAmount),
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "FCFA",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Objectif final : ${formatFCFA(cycle!.targetAmount)} FCFA",
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: AppTheme.accentDarkColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Épargne bloquée jusqu'à terme (31j)",
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Boutons d'action compacts : uniquement icônes pour économiser de la place
              if (onDepositTap != null || onStopTap != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDepositTap != null)
                      Material(
                        color: Colors.transparent,
                        child: Tooltip(
                          message: "Cotiser",
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onDepositTap?.call();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentColor.withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.savings_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (onDepositTap != null && onStopTap != null)
                      const SizedBox(width: 8),
                    if (onStopTap != null)
                      Material(
                        color: Colors.transparent,
                        child: Tooltip(
                          message: "Arrêter le cycle",
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onStopTap?.call();
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.errorColor.withValues(alpha: 0.28),
                                ),
                              ),
                              child: const Icon(
                                Icons.stop_circle_outlined,
                                color: AppTheme.errorColor,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: cycle!.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F4F8),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: "Mise / jour",
                    value: "${formatFCFA(cycle!.stakeAmount)} F",
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _HeroMetric(
                    label: "Progression",
                    value: "${(cycle!.progress * 100).toInt()}%",
                    highlightColor: AppTheme.accentDarkColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 26,
                  color: const Color(0xFFE2E8F0),
                ),
                Expanded(
                  child: _HeroMetric(
                    label: "Net à terme",
                    value: "${formatFCFA(cycle!.netPayoutAmount)} F",
                  ),
                ),
              ],
            ),
          ),

          // Lien cliquable vers le carnet de pointage (ouvre la modale)
          if (onCarnetTap != null) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCarnetTap?.call();
                },
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: AppTheme.accentDarkColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Carnet de pointage",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      Text(
                        "$paidDays / $totalDays jours",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentDarkColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? highlightColor;

  const _HeroMetric({
    required this.label,
    required this.value,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlightColor ?? AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }
}

class _TontineInfoPanel extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _TontineInfoPanel({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _AmountLine({
    required this.label,
    required this.value,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
              color: isHighlighted ? AppTheme.accentColor : AppTheme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalTontineTab extends StatelessWidget {
  final TontineCycle? cycle;
  final double availableBalance;
  final List<TontineHistoryEntry> history;
  final Widget Function(
    BuildContext context,
    TontineCycle? cycle,
    double availableBalance,
  )
  buildActionArea;
  final VoidCallback? onDepositTap;
  final VoidCallback? onStopTap;
  final VoidCallback? onCarnetTap;
  final VoidCallback? onSeeAllTap;

  const _PersonalTontineTab({
    required this.cycle,
    required this.availableBalance,
    required this.history,
    required this.buildActionArea,
    this.onDepositTap,
    this.onStopTap,
    this.onCarnetTap,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveCycle = cycle != null &&
        cycle!.status == TontineCycleStatus.active;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasActiveCycle) ...[
            _TontineHeroCard(
              cycle: cycle,
              onDepositTap: onDepositTap,
              onStopTap: onStopTap,
              onCarnetTap: onCarnetTap,
            ),
            const SizedBox(height: 24),
          ] else ...[
            buildActionArea(context, cycle, availableBalance),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Historique",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              if (onSeeAllTap != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSeeAllTap?.call();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Voir tout",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentDarkColor,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: AppTheme.accentDarkColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TontineHistoryList(history: history),
          ),
        ],
      ),
    );
  }
}

class _GroupTontineTab extends StatelessWidget {
  const _GroupTontineTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Mes groupes de tontine",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          const MyGroupsSection(),
        ],
      ),
    );
  }
}

class _AdhesionsTontineTab extends StatelessWidget {
  final ValueChanged<int>? onInvitationCountChanged;
  final ValueChanged<int>? onRequestCountChanged;

  const _AdhesionsTontineTab({
    this.onInvitationCountChanged,
    this.onRequestCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Adhésions & Invitations",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          UnifiedAdhesionsSection(
            onInvitationCountChanged: onInvitationCountChanged,
            onRequestCountChanged: onRequestCountChanged,
          ),
        ],
      ),
    );
  }
}

class _CountTabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _CountTabLabel({
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentColor,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentDarkColor.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineSheetError extends StatelessWidget {
  final String message;

  const _InlineSheetError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFFB71C1C),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}
