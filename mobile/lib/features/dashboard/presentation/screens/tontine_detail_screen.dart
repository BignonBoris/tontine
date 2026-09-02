import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:mobile/features/dashboard/presentation/widgets/tontine_history_list.dart';
import 'package:mobile/features/groups/presentation/widgets/my_groups_section.dart';
import 'package:mobile/features/groups/presentation/widgets/pending_group_requests_section.dart';
import 'package:mobile/features/groups/presentation/widgets/pending_group_invitations_section.dart';
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
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: AppBar(
            automaticallyImplyLeading: widget.showBackButton,
            title: Text(
              "Tontine",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            actions: _tabController.index == 0
                ? [
                    IconButton(
                      icon: const Icon(Icons.history_rounded),
                      onPressed: () => _showTontineArchives(
                        context,
                        state.tontineArchives,
                      ),
                    ),
                  ]
                : _tabController.index == 2
                    ? [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/group-scanner'),
                        ),
                      ]
                    : const [],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondaryColor,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: [
                    const Tab(text: 'Personnel'),
                    const Tab(text: 'Groupe'),
                    Tab(
                      child: _CountTabLabel(
                        label: 'Adhesions',
                        count: _adhesionPendingCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _PersonalTontineTab(
                cycle: cycle,
                availableBalance: state.availableBalance,
                history: state.tontineHistory,
                buildActionArea: (context, cycle, availableBalance) =>
                    _buildActionArea(context, cycle, availableBalance),
              ),
              const _GroupTontineTab(),
              _AdhesionsTontineTab(
                onInvitationCountChanged: _handleInvitationCountChanged,
                onRequestCountChanged: _handleRequestCountChanged,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionArea(
    BuildContext context,
    TontineCycle? cycle,
    double availableBalance,
  ) {
    if (cycle == null) {
      return _TontineInfoPanel(
        title: "Aucune tontine en cours",
        description:
            "Vous n avez pas encore de cycle de tontine actif. Configurez votre mise pour lancer un nouveau cycle.",
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _showRestartTontineModal(context),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text("Configurer ma tontine"),
          ),
        ),
      );
    }

    if (cycle.status == TontineCycleStatus.nonConfiguree) {
      return _TontineInfoPanel(
        title: "Aucune tontine en cours",
        description:
            "Vous n avez pas encore de cycle de tontine actif. Configurez votre mise pour lancer un nouveau cycle.",
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _showRestartTontineModal(context),
            icon: const Icon(Icons.tune_rounded),
            label: const Text("Configurer ma tontine"),
          ),
        ),
      );
    }

    if (cycle.status == TontineCycleStatus.enAttenteValidationFin) {
      return _TontineInfoPanel(
        title: "Cycle atteint",
        description:
            "Votre objectif est complete. Confirmez le reversement vers le solde disponible.",
        child: Column(
          children: [
            _AmountLine(
              label: "Total cumule",
              value: "${formatFCFA(cycle.cumulativeAmount)} F",
            ),
            _AmountLine(
              label: "Commission plateforme",
              value: "${formatFCFA(cycle.commissionAmount)} F",
            ),
            _AmountLine(
              label: "Montant reverse",
              value: "${formatFCFA(cycle.netPayoutAmount)} F",
              isHighlighted: true,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
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
                child: const Text("Confirmer le reversement"),
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
            "Ce cycle n'accepte plus de versement. Reconfigurez une nouvelle mise depuis le dashboard pour repartir a zero.",
        child: Column(
          children: [
            _AmountLine(
              label: "Dernier montant net de cycle",
              value: "${formatFCFA(cycle.netPayoutAmount)} F",
              isHighlighted: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showRestartTontineModal(context),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Recommencer une tontine"),
              ),
            ),
          ],
        ),
      );
    }

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
      child: Row(
        children: [
          TontineActionButton(
            label: "Verser",
            icon: Icons.add_circle_outline_rounded,
            color: AppTheme.secondaryColor,
            onTap: () =>
                _showDepositSheetWithPaymentMethods(
                  context,
                  cycle,
                  availableBalance,
                ),
          ),
          const SizedBox(width: 12),
          TontineActionButton(
            label: "Arreter",
            icon: Icons.pause_circle_outline_rounded,
            color: AppTheme.errorColor,
            onTap: () => _showEarlyStopDialog(context, cycle),
          ),
        ],
      ),
    );
  }

  void _showDepositSheet(
    BuildContext context,
    TontineCycle cycle,
    double availableBalance,
  ) {
    final controller = TextEditingController();
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                "Transferer vers la tontine",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Le montant sera preleve de votre solde disponible. Il doit etre un multiple de ${AppInputRules.financialAmountStep} et ne peut pas depasser l'objectif du cycle.",
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 14),
                _InlineSheetError(message: errorMessage!),
              ],
              const SizedBox(height: 20),
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
                  labelText: "Montant a verser",
                  suffixText: "F CFA",
                  helperText:
                      "Disponible : ${formatFCFA(availableBalance)} F • Reste : ${formatFCFA((cycle.targetAmount - cycle.cumulativeAmount).toInt())} F",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(controller.text);
                    final remaining =
                        cycle.targetAmount - cycle.cumulativeAmount;

                    if (amount == null || amount <= 0) {
                      setSheetState(() => errorMessage = "Montant invalide");
                      return;
                    }
                    if (amount % AppInputRules.financialAmountStep != 0) {
                      setSheetState(
                        () => errorMessage =
                            "Le montant doit etre un multiple de ${AppInputRules.financialAmountStep}",
                      );
                      return;
                    }
                    if (amount > remaining) {
                      setSheetState(
                        () => errorMessage =
                            "Le montant depasse l'objectif restant",
                      );
                      return;
                    }
                    if (amount > availableBalance) {
                      setSheetState(
                        () => errorMessage =
                            "Solde disponible insuffisant",
                      );
                      return;
                    }

                    final authorized =
                        await LocalSecurityService.authorizeIfEnabled(
                          context,
                          title: 'Transferer vers la tontine',
                          message:
                              "Entrez votre PIN pour confirmer ce versement dans votre tontine.",
                        );
                    if (!context.mounted || !authorized) {
                      return;
                    }

                    context.read<DashboardBloc>().add(
                      MakeTontineDeposit(amount),
                    );
                    Navigator.pop(modalContext);
                  },
                  child: const Text("Confirmer le transfert"),
                ),
              ),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    top: 24,
                    bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verser dans la tontine',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisissez le mode de paiement. Le montant doit etre un multiple de ${AppInputRules.financialAmountStep} et ne peut pas depasser le reste a verser du cycle.',
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 13,
                          height: 1.4,
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
                              ? 'Montant a transferer'
                              : 'Montant a payer',
                          suffixText: 'F CFA',
                          helperText: selectedMethod.code == 'wallet'
                              ? 'Disponible : ${formatFCFA(availableBalance)} F - Reste : ${formatFCFA(remaining.toInt())} F'
                              : 'Paiement externe - Reste a verser : ${formatFCFA(remaining.toInt())} F',
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _InlineSheetError(message: errorMessage!),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : submitDeposit,
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_depositActionLabel(selectedMethod.code)),
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

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Arreter la tontine ?"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountLine(
                label: "Cumul actuel",
                value: "${formatFCFA(cycle.cumulativeAmount)} F",
              ),
              _AmountLine(
                label: "Commission",
                value: "${formatFCFA(cycle.commissionAmount)} F",
              ),
              _AmountLine(
                label: "Montant reverse",
                value: "${formatFCFA(netAmount)} F",
                isHighlighted: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                final authorized = await LocalSecurityService.authorizeIfEnabled(
                  context,
                  title: 'Arreter la tontine',
                  message:
                      "Entrez votre PIN pour confirmer l'arret anticipe de cette tontine.",
                );
                if (!context.mounted || !authorized) {
                  return;
                }
                context.read<DashboardBloc>().add(StopTontineEarly());
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text("Confirmer l'arret"),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRestartTontineModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return ConfigureTontineStakeModal(
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tontines precedentes",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              if (archives.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "Aucune tontine precedente.",
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: archives.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final archive = archives[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.1,
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(
                          "Objectif ${formatFCFA(archive.targetAmount)} F",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "Debut ${DateFormat('dd/MM/yyyy').format(archive.startDate)} - Fin ${DateFormat('dd/MM/yyyy').format(archive.endDate)}",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
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
        ? "Cycle termine"
        : "Arret anticipe";

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(statusLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AmountLine(
                label: "Date de debut",
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
                label: "Total cumule",
                value: "${formatFCFA(archive.cumulativeAmount)} F",
              ),
              _AmountLine(
                label: "Commission",
                value: "${formatFCFA(archive.commissionAmount)} F",
              ),
              _AmountLine(
                label: "Montant reverse",
                value: "${formatFCFA(archive.netPayoutAmount)} F",
                isHighlighted: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }
}

class _TontineHeroCard extends StatelessWidget {
  final TontineCycle? cycle;

  const _TontineHeroCard({required this.cycle});

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
              "Reconfigurez une mise pour relancer un cycle depuis le dashboard.",
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF26359C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabel(cycle!.status),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${formatFCFA(cycle!.cumulativeAmount)} F",
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Objectif ${formatFCFA(cycle!.targetAmount)} F",
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: cycle!.progress,
              minHeight: 10,
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.secondaryColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: "Mise actuelle",
                  value: "${formatFCFA(cycle!.stakeAmount)} F",
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: "Progression",
                  value: "${(cycle!.progress * 100).toInt()}%",
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: "Net fin cycle",
                  value: "${formatFCFA(cycle!.netPayoutAmount)} F",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(TontineCycleStatus status) {
    switch (status) {
      case TontineCycleStatus.nonConfiguree:
        return "Non configuree";
      case TontineCycleStatus.active:
        return "Cycle actif";
      case TontineCycleStatus.enAttenteValidationFin:
        return "En attente de confirmation";
      case TontineCycleStatus.terminee:
        return "Cycle termine";
      case TontineCycleStatus.arretee:
        return "Cycle arretee";
    }
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
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
              height: 1.4,
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
              fontWeight: FontWeight.w700,
              color: isHighlighted ? AppTheme.secondaryColor : Colors.black87,
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

  const _PersonalTontineTab({
    required this.cycle,
    required this.availableBalance,
    required this.history,
    required this.buildActionArea,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveCycle = cycle != null &&
        cycle!.status != TontineCycleStatus.nonConfiguree;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasActiveCycle) ...[
            _TontineHeroCard(cycle: cycle),
            const SizedBox(height: 20),
          ],
          buildActionArea(context, cycle, availableBalance),
          const SizedBox(height: 24),
          Text(
            "Historique tontine",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
            child: TontineHistoryList(history: history),
          ),
        ],
      ),
    );
  }
}

class _GroupTontineTab extends StatelessWidget {
  const _GroupTontineTab({super.key});

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
            "Invitations de groupe",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          PendingGroupInvitationsSection(
            onCountChanged: onInvitationCountChanged,
          ),
          const SizedBox(height: 24),
          Text(
            "Demandes envoyees",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          PendingGroupRequestsSection(
            onCountChanged: onRequestCountChanged,
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
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 11,
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
