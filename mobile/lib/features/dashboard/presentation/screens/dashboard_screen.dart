import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/screens/available_balance_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/goal_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/notifications_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/tontine_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/utils/market_offer_detail_launcher.dart';
import 'package:mobile/features/dashboard/presentation/widgets/add_goal_dialog.dart';
import 'package:mobile/features/dashboard/presentation/widgets/balance_card_widget.dart';
import 'package:mobile/features/dashboard/presentation/widgets/configure_tontine_stake_modal.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/goal_card.dart';
import 'package:mobile/features/dashboard/presentation/widgets/scan_simulation_dialog.dart';
import 'package:mobile/features/dashboard/presentation/widgets/section_header.dart';
import 'package:mobile/features/dashboard/presentation/widgets/shimmer_loading.dart';
import 'package:mobile/features/dashboard/presentation/widgets/tontine_cycle_list_item.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenMarketplaceTab;
  final VoidCallback? onOpenTontineTab;

  const DashboardScreen({
    super.key,
    this.onOpenMarketplaceTab,
    this.onOpenTontineTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final PageController _marketplaceController;
  Timer? _marketplaceTimer;
  int _currentMarketplaceIndex = 0;

  @override
  void initState() {
    super.initState();
    _marketplaceController = PageController(viewportFraction: 0.88);
    _startMarketplaceAutoSlide();
  }

  @override
  void dispose() {
    _marketplaceTimer?.cancel();
    _marketplaceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
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
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Image.asset(AppTheme.brandIconAsset),
            ),
            const SizedBox(width: 10),
            const _DashboardWordmark(),
          ],
        ),
        actions: [
          BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              final unreadCount = state is DashboardLoaded
                  ? state.notifications.where((item) => !item.isRead).length
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: () {
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
                            color: Color(0xFFE53935),
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
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const _DashboardLoadingView();
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
              label: "Preparation de votre espace...",
            );
          }

          final activeGoals = state.goals
              .where((goal) => goal.status == GoalStatus.active)
              .toList();
          final offers = state.marketOffers;

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async {
              context.read<DashboardBloc>().add(LoadDashboardData());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  BalanceCardWidget(
                    availableBalance: state.availableBalance,
                    tontineBalance: state.tontineBalance,
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
                  const SizedBox(height: 16),
                  TontineCycleListItem(
                    cycle: state.tontineCycle,
                    onTap: () {
                      widget.onOpenTontineTab?.call();
                    },
                    onRestartPressed: () {
                      _showStakeConfigurationModal(context);
                    },
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: "Mes Objectifs",
                    onActionPressed: () => showScanSimulation(
                      context,
                      context.read<DashboardBloc>(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 158,
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
                        return GestureDetector(
                          onTap: () {
                            final bloc = context.read<DashboardBloc>();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BlocProvider.value(
                                  value: bloc,
                                  child: GoalDetailScreen(goalId: goal.id),
                                ),
                              ),
                            );
                          },
                          child: GoalCard(goal: goal),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 238,
                      child: PageView.builder(
                        controller: _marketplaceController,
                        itemCount: offers.length,
                        onPageChanged: (index) {
                          _currentMarketplaceIndex = index;
                        },
                        itemBuilder: (context, index) {
                          final offer = offers[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () =>
                                  showMarketOfferDetailLauncher(context, index),
                              child: MarketOfferGridCard(
                                offer: offer,
                                formattedPrice: formatFCFA(offer.price ?? 0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showStakeConfigurationModal(BuildContext context) async {
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

  void _startMarketplaceAutoSlide() {
    _marketplaceTimer?.cancel();
    _marketplaceTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_marketplaceController.hasClients) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.network(
              offer.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.category,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
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
                Text(
                  offer.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$formattedPrice F CFA",
                  style: const TextStyle(
                    color: AppTheme.secondaryVariantColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
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
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 140,
        height: 128,
        margin: const EdgeInsets.only(right: 12, bottom: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.08), width: 1.2),
        ),
        child: InkWell(
          onTap: () {
            showAddGoalDialog(context, bloc);
          },
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.accentColor,
                size: 34,
              ),
              const SizedBox(height: 6),
              Text(
                "Nouveau",
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
