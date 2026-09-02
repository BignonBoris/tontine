import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:mobile/core/widgets/cached_remote_image.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/screens/available_balance_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/goal_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/goals_list_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/dashboard/presentation/utils/market_offer_detail_launcher.dart';
import 'package:mobile/features/dashboard/presentation/widgets/add_goal_dialog.dart';
import 'package:mobile/features/dashboard/presentation/widgets/client_qr_modal.dart';
import 'package:mobile/features/dashboard/presentation/widgets/configure_tontine_stake_modal.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_goals_selection_screen.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_sliver_header.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/goal_card.dart';
import 'package:mobile/features/dashboard/presentation/widgets/quick_actions_bar.dart';
import 'package:mobile/features/dashboard/presentation/widgets/scan_simulation_dialog.dart';
import 'package:mobile/features/dashboard/presentation/widgets/section_header.dart';
import 'package:mobile/features/dashboard/presentation/widgets/shimmer_loading.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_cycle_list_item.dart';
import 'package:mobile/features/dashboard/presentation/widgets/vizio_spotlight_overlay.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenMarketplaceTab;
  final VoidCallback? onOpenTontineTab;
  final VoidCallback? onOpenProfileTab;
  final bool skipOnboarding;

  const DashboardScreen({
    super.key,
    this.onOpenMarketplaceTab,
    this.onOpenTontineTab,
    this.onOpenProfileTab,
    this.skipOnboarding = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  static const String _tutorialSeenPrefKey =
      'app.dashboard_spotlight_tutorial_seen';

  late final PageController _marketplaceController;
  Timer? _marketplaceTimer;
  int _currentMarketplaceIndex = 0;
  
  Timer? _backgroundFetchTimer;

  // Clés cibles pour le tutoriel pas-à-pas interactif
  final GlobalKey _headerProfileKey = GlobalKey();
  final GlobalKey _balancesKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();
  final GlobalKey _tontineCycleKey = GlobalKey();
  final GlobalKey _goalsSectionKey = GlobalKey();
  final GlobalKey _marketplaceKey = GlobalKey();

  bool _showSpotlightTutorial = false;
  bool _hasCheckedTutorial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _marketplaceController = PageController(viewportFraction: 0.88);
    _startMarketplaceAutoSlide();
    _startBackgroundFetch();
  }

  void _startBackgroundFetch() {
    _backgroundFetchTimer?.cancel();
    _backgroundFetchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardData(isSilent: true));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _marketplaceTimer?.cancel();
    _backgroundFetchTimer?.cancel();
    _marketplaceController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // WCAG 2.2.2 / économie de batterie : suspendre le défilement automatique
    // du carrousel lorsque l'application passe en arrière-plan.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _marketplaceTimer?.cancel();
      _backgroundFetchTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _startMarketplaceAutoSlide();
      _startBackgroundFetch();
      if (mounted) {
        context.read<DashboardBloc>().add(LoadDashboardData(isSilent: true));
      }
    }
  }

  /// Déclenche le tutoriel interactif uniquement lors de la première arrivée
  /// sur le tableau de bord (flag persisté dans SharedPreferences).
  Future<void> _checkAndLaunchTutorial() async {
    if (_hasCheckedTutorial) return;
    _hasCheckedTutorial = true;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_tutorialSeenPrefKey) ?? false;

    if (!seen && mounted) {
      // Pause de stabilisation du rendu initial de l'écran
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() {
          _showSpotlightTutorial = true;
        });
      }
    }
  }

  Future<void> _dismissTutorial() async {
    HapticFeedback.selectionClick();
    setState(() => _showSpotlightTutorial = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tutorialSeenPrefKey, true);
  }

  List<SpotlightStep> _buildTutorialSteps() {
    return [
      SpotlightStep(
        targetKey: _headerProfileKey,
        title: 'Profil & Notifications',
        description:
            'Consultez vos informations personnelles, votre statut KYC et toutes vos alertes en temps réel.',
        icon: Icons.person_outline_rounded,
        category: 'Votre Espace',
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      SpotlightStep(
        targetKey: _balancesKey,
        title: 'Soldes & Portefeuille',
        description:
            'Suivez votre solde disponible et votre épargne en tontine. Masquez vos montants à tout moment avec l\'icône œil.',
        icon: Icons.account_balance_wallet_outlined,
        category: 'Finances',
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      SpotlightStep(
        targetKey: _quickActionsKey,
        title: 'Dépôts & Actions Rapides',
        description:
            'Scannez le QR code de votre agent pour effectuer vos versements, demandez un retrait ou affichez votre QR membre.',
        icon: Icons.qr_code_scanner_rounded,
        category: 'Opérations',
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(4),
      ),
      SpotlightStep(
        targetKey: _tontineCycleKey,
        title: 'Cycle de Tontine en Cours',
        description:
            'Consultez votre tour de ramassage, vos cotisations journalières et la progression de votre cagnotte.',
        icon: Icons.restart_alt_rounded,
        category: 'Tontine',
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(4),
      ),
      SpotlightStep(
        targetKey: _goalsSectionKey,
        title: 'Mes Coffres',
        description:
            'Vos boxs de projet sont prêtes ! Cliquez sur [+] pour effectuer votre tout premier versement d\'épargne.',
        icon: Icons.savings_outlined,
        category: 'Objectifs',
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(6),
      ),
      SpotlightStep(
        targetKey: _marketplaceKey,
        title: 'Offres du Marketplace',
        description:
            'Transformez votre épargne en biens utiles et équipements exclusifs proposés par nos marchands partenaires.',
        icon: Icons.storefront_outlined,
        category: 'Marketplace',
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(6),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocConsumer<DashboardBloc, DashboardState>(
        listener: (context, state) {
          // Redirection une seule fois dès que les données sont chargées
          // et qu'il n'y a pas de coffres actifs.
          if (state is DashboardLoaded && !widget.skipOnboarding) {
            final activeGoals = state.goals
                .where((goal) => goal.status == GoalStatus.active)
                .toList();
            if (activeGoals.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  Navigator.of(context).pushNamed('/onboarding_goals');
                }
              });
            }
          }
          // Déclencher le tutoriel interactif APRÈS le frame courant.
          if (state is DashboardLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkAndLaunchTutorial();
            });
          }
        },
        // listenWhen: ne réagir qu'au premier passage en DashboardLoaded
        listenWhen: (previous, current) =>
            current is DashboardLoaded && previous is! DashboardLoaded,
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const _DashboardLoadingView();
          }

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
            return const _DashboardLoadingView();
          }

          final activeGoals = state.goals
              .where((goal) => goal.status == GoalStatus.active)
              .toList();

          // Si pas de coffres, afficher un loader pendant que le listener redirige.
          if (activeGoals.isEmpty && !widget.skipOnboarding) {
            return const _DashboardLoadingView();
          }

          final offers = state.marketOffers;
          final unreadNotificationsCount =
              state.notifications.where((item) => !item.isRead).length;


          return Stack(
            children: [
              RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: () async {
                  context.read<DashboardBloc>().add(LoadDashboardData());
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Header Immergé Sticky Bleu Nuit Signature VizioBox (Option 2 - Mode Fixe B)
                    DashboardSliverHeader(
                      availableBalance: state.availableBalance,
                      tontineBalance: state.tontineBalance,
                      profile: state.profile,
                      profileKey: _headerProfileKey,
                      balancesKey: _balancesKey,
                      onProfileTap: () {
                        widget.onOpenProfileTab?.call();
                      },
                      unreadNotificationsCount: unreadNotificationsCount,
                      onNotificationsTap: () {
                        final bloc = context.read<DashboardBloc>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: bloc,
                              child: const NotificationsScreen(),
                            ),
                          ),
                        );
                      },
                      onAvailableTap: () {
                        final bloc = context.read<DashboardBloc>();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BlocProvider.value(
                              value: bloc,
                              child: const AvailableBalanceDetailScreen(),
                            ),
                          ),
                        );
                      },
                      onTontineTap: () {
                        widget.onOpenTontineTab?.call();
                      },
                    ),

                    // Corps Scrollable avec espacement
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          [
                            const SizedBox(height: 14),
                            if (state.statusMessage != null) ...[
                              _DashboardStatusBanner(
                                message: state.statusMessage!,
                                statusVariant: state.statusVariant,
                                isSyncing: state.isSyncing,
                                lastSyncedAt: state.lastSyncedAt,
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Actions Rapides
                            KeyedSubtree(
                              key: _quickActionsKey,
                              child: QuickActionsBar(
                                onDepositPressed: () => showScanSimulation(
                                  context,
                                  context.read<DashboardBloc>(),
                                ),
                                onWithdrawPressed: () {
                                  final bloc = context.read<DashboardBloc>();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BlocProvider.value(
                                        value: bloc,
                                        child:
                                            const AvailableBalanceDetailScreen(),
                                      ),
                                    ),
                                  );
                                },
                                onHistoryPressed: () {
                                  widget.onOpenTontineTab?.call();
                                },
                                onQrPressed: () {
                                  ClientQrModal.show(context);
                                },
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Cycle de Tontine
                            KeyedSubtree(
                              key: _tontineCycleKey,
                              child: TontineCycleListItem(
                                cycle: state.tontineCycle,
                                onTap: () {
                                  widget.onOpenTontineTab?.call();
                                },
                                onRestartPressed: () {
                                  _showStakeConfigurationModal(context);
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Section Mes Objectifs (Boxs d'Épargne)
                            KeyedSubtree(
                              key: _goalsSectionKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionHeader(
                                    title: "Mes Coffres",
                                    actionLabel: "Voir tout",
                                    onActionPressed: () {
                                      final bloc =
                                          context.read<DashboardBloc>();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: bloc,
                                            child: const GoalsListScreen(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 156,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: activeGoals.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == activeGoals.length) {
                                          return AddGoalPlaceholder(
                                            bloc: context.read<DashboardBloc>(),
                                          );
                                        }

                                        final goal = activeGoals[index];
                                        return GoalCard(
                                          goal: goal,
                                          onTap: () {
                                            final bloc =
                                                context.read<DashboardBloc>();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    BlocProvider.value(
                                                  value: bloc,
                                                  child: GoalDetailScreen(
                                                      goalId: goal.id),
                                                ),
                                              ),
                                            );
                                          },
                                          onQuickDeposit: () {
                                            _showQuickGoalDepositSheet(
                                              context,
                                              goal,
                                              state.availableBalance,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Section Marketplace
                            KeyedSubtree(
                              key: _marketplaceKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SectionHeader(
                                    title: "Marketplace",
                                    actionLabel: "Voir tout",
                                    onActionPressed: () {
                                      widget.onOpenMarketplaceTab?.call();
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  if (offers.isEmpty)
                                    Container(
                                      height: 160,
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "Aucun article disponible pour le moment.",
                                        style: GoogleFonts.inter(
                                          color: AppTheme.textSecondaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      height: 275,
                                      child: NotificationListener<
                                          ScrollEndNotification>(
                                        onNotification: (_) {
                                          _startMarketplaceAutoSlide();
                                          return false;
                                        },
                                        child: PageView.builder(
                                          controller: _marketplaceController,
                                          itemCount: offers.length,
                                          onPageChanged: (index) {
                                            _currentMarketplaceIndex = index;
                                          },
                                          itemBuilder: (context, index) {
                                            final offer = offers[index];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 12),
                                              child: GestureDetector(
                                                onTap: () =>
                                                    showMarketOfferDetailLauncher(
                                                        context, index),
                                                child: MarketOfferGridCard(
                                                  offer: offer,
                                                  formattedPrice: formatFCFA(
                                                      offer.price ?? 0),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Overlay du tutoriel interactif
              if (_showSpotlightTutorial)
                VizioSpotlightOverlay(
                  steps: _buildTutorialSteps(),
                  onFinish: _dismissTutorial,
                  onSkip: _dismissTutorial,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showStakeConfigurationModal(BuildContext context) async {
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
          onSubmit: (amount, termsAccepted) async {
            context.read<DashboardBloc>().add(ConfigureTontineStake(amount, termsAccepted: termsAccepted));
          },
        );
      },
    );
  }

  void _showQuickGoalDepositSheet(
    BuildContext context,
    TontineGoal goal,
    double availableBalance,
  ) {
    final amountController = TextEditingController();
    final bloc = context.read<DashboardBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec Icône & Titre
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(goal.icon, color: goal.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Alimenter le coffre",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            Text(
                              goal.title,
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Solde disponible
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Solde disponible :",
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        Text(
                          "${formatFCFA(availableBalance.toInt())} FCFA",
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pastilles de montants rapides
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1000, 2000, 5000, 10000].map((preset) {
                      return ActionChip(
                        label: Text(
                          // ISO 4217 : "FCFA" explicite (éviter l'abbréviation "F").
                          "+${formatFCFA(preset)} FCFA",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        // Cible tactile élargie (~40 dp vs 32 dp par défaut).
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color:
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          amountController.text = preset.toString();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Champ de saisie
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: AppInputRules.amountFormatters,
                    autofocus: true,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: "Montant à verser (FCFA)",
                      hintText: "Ex: 5000",
                      prefixIcon: const Icon(
                        Icons.savings_rounded,
                        color: AppTheme.accentColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bouton de confirmation
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        final amount = double.tryParse(
                          amountController.text.trim().replaceAll(' ', ''),
                        );
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text("Veuillez saisir un montant valide."),
                            ),
                          );
                          return;
                        }
                        if (amount > availableBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text("Solde disponible insuffisant."),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(modalContext);
                        bloc.add(
                          AddFundsToGoal(goal.id, amount),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Dépôt de ${formatFCFA(amount.toInt())} FCFA versé dans « ${goal.title} » !",
                              // WCAG 1.4.3 : blanc sur successColor = 5.13:1
                              // (blanc sur secondaryColor = 2.38:1 échouait).
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      },
                      child: Text(
                        "Confirmer le versement",
                        style: GoogleFonts.inter(
                          fontSize: 14.5,
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
        );
      },
    );
  }

  void _startMarketplaceAutoSlide() {
    _marketplaceTimer?.cancel();
    _marketplaceTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_marketplaceController.hasClients) {
        return;
      }

      // WCAG 2.2.2 / 2.3.3 : respecter la préférence OS "Réduire les
      // animations" — le carrousel cesse de défiler automatiquement.
      if (MediaQuery.disableAnimationsOf(context)) {
        return;
      }

      final blocState = context.read<DashboardBloc>().state;
      if (blocState is! DashboardLoaded || blocState.marketOffers.isEmpty) {
        return;
      }

      final nextIndex =
          (_currentMarketplaceIndex + 1) % blocState.marketOffers.length;
      _marketplaceController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    // SafeArea : les skeletons ne passent plus sous la barre de statut.
    return SafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const ShimmerBox(
              height: 160,
              width: double.infinity,
              borderRadius: 25,
            ),
            const SizedBox(height: 24),
            const ShimmerBox(
              height: 155,
              width: double.infinity,
              borderRadius: 20,
            ),
            const SizedBox(height: 32),
            const ShimmerBox(height: 20, width: 150),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                2,
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: ShimmerBox(height: 200, width: 150, borderRadius: 24),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const ShimmerBox(height: 20, width: 120),
          ],
        ),
      ),
    );
  }
}

class MarketOfferGridCard extends StatelessWidget {
  final MarketOffer offer;
  final String formattedPrice;

  const MarketOfferGridCard({
    super.key,
    required this.offer,
    required this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedRemoteImage(
              imageUrl: offer.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.category.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      offer.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$formattedPrice FCFA",
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddGoalPlaceholder extends StatelessWidget {
  final DashboardBloc bloc;

  const AddGoalPlaceholder({super.key, required this.bloc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 148,
      margin: const EdgeInsets.only(right: 12, bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            showAddGoalDialog(context, bloc);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppTheme.accentDarkColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Nouveau Coffre",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Créer un projet",
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/*
// Ancien Wordmark du logo VizioBox (conservé en commentaire) :
class _DashboardWordmark extends StatelessWidget {
  const _DashboardWordmark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        children: [
          const TextSpan(
            text: 'V',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Text(
                    'i',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Positioned(
                    top: -1,
                    left: 4,
                    child: CustomPaint(
                      size: const Size(7, 5),
                      painter: _InvertedTrianglePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const TextSpan(
            text: 'zio',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
          const TextSpan(
            text: 'Box',
            style: TextStyle(color: AppTheme.accentColor),
          ),
        ],
      ),
    );
  }
}
*/

class _DashboardStatusBanner extends StatelessWidget {
  final String message;
  final DashboardStatusVariant statusVariant;
  final bool isSyncing;
  final DateTime? lastSyncedAt;

  const _DashboardStatusBanner({
    required this.message,
    required this.statusVariant,
    required this.isSyncing,
    required this.lastSyncedAt,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _accentColor(statusVariant);
    final backgroundColor = accentColor.withValues(alpha: 0.10);
    final borderColor = accentColor.withValues(alpha: 0.20);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSyncing)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: accentColor,
              ),
            )
          else
            Icon(
              _iconFor(statusVariant),
              color: accentColor,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                    height: 1.35,
                  ),
                ),
                if (lastSyncedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Dernière synchro : ${DateFormat('dd/MM/yyyy HH:mm').format(lastSyncedAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                      height: 1.3,
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

  Color _accentColor(DashboardStatusVariant variant) {
    return switch (variant) {
      DashboardStatusVariant.info => AppTheme.primaryColor,
      // Token sémantique conforme (B45309 = 4.58:1 sur teinte claire,
      // l'ancien E65100 tombait à ~2.8:1 pour l'icône).
      DashboardStatusVariant.warning => AppTheme.warningColor,
      DashboardStatusVariant.error => AppTheme.errorColor,
    };
  }

  IconData _iconFor(DashboardStatusVariant variant) {
    return switch (variant) {
      DashboardStatusVariant.info => Icons.sync_rounded,
      DashboardStatusVariant.warning => Icons.cloud_off_rounded,
      DashboardStatusVariant.error => Icons.error_outline_rounded,
    };
  }
}

/*
class _InvertedTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.accentColor;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
*/
