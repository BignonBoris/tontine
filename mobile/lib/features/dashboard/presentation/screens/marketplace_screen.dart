import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/screens/goal_detail_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/market_orders_screen.dart';
import 'package:mobile/features/dashboard/presentation/screens/marketplace_favorites_screen.dart';
import 'package:mobile/features/dashboard/presentation/utils/marketplace_offer_filter.dart';
import 'package:mobile/features/dashboard/presentation/widgets/market_offer_detail_sheet.dart';
import 'package:mobile/features/dashboard/presentation/widgets/marketplace_category_chips.dart';
import 'package:mobile/features/dashboard/presentation/widgets/marketplace_hero_section.dart';
import 'package:mobile/features/dashboard/presentation/widgets/marketplace_offer_compact_card.dart';
import 'package:mobile/features/dashboard/presentation/widgets/marketplace_search_delegate.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';

class MarketplaceScreen extends StatefulWidget {
  final bool showBackButton;

  const MarketplaceScreen({super.key, this.showBackButton = true});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardError) {
          return DashboardErrorView(
            title: state.title,
            message: state.message,
            requiresReauthentication: state.requiresReauthentication,
          );
        }

        if (state is! DashboardLoaded) {
          return const DashboardLoadingView(
            label: "Chargement du marketplace...",
          );
        }

        final offers = state.marketOffers;
        final categories = offers
            .map((offer) => offer.category)
            .toSet()
            .toList();
        final visibleOffers = filterMarketplaceOffers(
          offers: offers,
          category: _selectedCategory,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FE),
          appBar: AppBar(
            automaticallyImplyLeading: widget.showBackButton,
            title: Text(
              "Marketplace",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                onPressed: () => _openSearch(context),
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                onPressed: () => _openFavorites(context),
                icon: Icon(
                  state.favoriteOfferIds.isEmpty
                      ? Icons.favorite_border_rounded
                      : Icons.favorite_rounded,
                  color: state.favoriteOfferIds.isEmpty
                      ? null
                      : const Color(0xFFD81B60),
                ),
              ),
              IconButton(
                onPressed: () => _openOrders(context),
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MarketplaceHeroSection(
                        availableBalance: state.availableBalance,
                      ),
                      const SizedBox(height: 18),
                      MarketplaceCategoryChips(
                        categories: categories,
                        selectedCategory: _selectedCategory,
                        onSelected: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      _SectionHeading(
                        title: "Tous les articles",
                        subtitle: visibleOffers.isEmpty
                            ? "Aucun article ne correspond a ce filtre."
                            : "Choisissez un article et passez a l'action.",
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              if (visibleOffers.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Center(
                      child: Text(
                        "Aucun article disponible pour cette selection.",
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent: 262,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final offer = visibleOffers[index];
                      return MarketplaceOfferCompactCard(
                        offer: offer,
                        isFavorite: state.favoriteOfferIds.contains(offer.id),
                        onTap: () => _showOfferDetailSheet(
                          context,
                          offers.indexWhere((item) => item.id == offer.id),
                        ),
                        onBuyNow: () => _handleBuyNow(context, offer),
                        onToggleFavorite: () {
                          _toggleFavorite(
                            context,
                            offer,
                            state.favoriteOfferIds,
                          );
                        },
                        onCreateGoal: () => _handleCreateGoal(context, offer),
                      );
                    }, childCount: visibleOffers.length),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    final blocState = context.read<DashboardBloc>().state;
    if (blocState is! DashboardLoaded) {
      return;
    }

    final offers = blocState.marketOffers;
    final selected = await showSearch<MarketOffer?>(
      context: context,
      delegate: MarketplaceSearchDelegate(offers: offers),
    );
    if (!context.mounted || selected == null) {
      return;
    }

    final selectedIndex = offers.indexWhere((offer) => offer.id == selected.id);
    if (selectedIndex >= 0) {
      _showOfferDetailSheet(context, selectedIndex);
    }
  }

  void _openOrders(BuildContext context) {
    final bloc = context.read<DashboardBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BlocProvider.value(value: bloc, child: const MarketOrdersScreen()),
      ),
    );
  }

  void _openFavorites(BuildContext context) {
    final bloc = context.read<DashboardBloc>();
    final blocState = bloc.state;
    if (blocState is! DashboardLoaded) {
      return;
    }
    final offers = blocState.marketOffers;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: MarketplaceFavoritesScreen(
            offers: offers,
            onOpenOffer: (offer) {
              final index = offers.indexWhere((item) => item.id == offer.id);
              if (index >= 0) {
                _showOfferDetailSheet(context, index);
              }
            },
            onBuyNow: (offer) => _handleBuyNow(context, offer),
            onCreateGoal: (offer) => _handleCreateGoal(context, offer),
          ),
        ),
      ),
    );
  }

  void _handleBuyNow(BuildContext context, MarketOffer offer) {
    final state = context.read<DashboardBloc>().state;
    if (state is! DashboardLoaded) {
      return;
    }

    _confirmMarketplaceOrder(context, offer, state.availableBalance);
  }

  void _handleCreateGoal(BuildContext context, MarketOffer offer) {
    _confirmAndCreateGoal(context, offer);
  }

  void _toggleFavorite(
    BuildContext context,
    MarketOffer offer,
    List<String> favoriteOfferIds,
  ) {
    final isFavorite = favoriteOfferIds.contains(offer.id);
    context.read<DashboardBloc>().add(ToggleMarketplaceFavorite(offer.id));
    _showSnackBar(
      context,
      isFavorite
          ? "${offer.title} retire des favoris"
          : "${offer.title} ajoute aux favoris",
    );
  }

  void _showOfferDetailSheet(BuildContext context, int initialIndex) {
    final state = context.read<DashboardBloc>().state;
    if (state is! DashboardLoaded || initialIndex < 0) {
      return;
    }

    final dashboardBloc = context.read<DashboardBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (sheetContext) {
        return MarketOfferDetailSheet(
          offers: state.marketOffers,
          initialIndex: initialIndex,
          availableBalance: state.availableBalance,
          favoriteOfferIds: state.favoriteOfferIds,
          onBuyNow: (offer) {
            final currentState = dashboardBloc.state;
            if (currentState is DashboardLoaded) {
              Navigator.pop(sheetContext);
              _confirmMarketplaceOrder(
                context,
                offer,
                currentState.availableBalance,
              );
            }
          },
          onToggleFavorite: (offer) {
            Navigator.pop(sheetContext);
            final currentState = dashboardBloc.state;
            final favoriteIds = currentState is DashboardLoaded
                ? currentState.favoriteOfferIds
                : const <String>[];
            _toggleFavorite(context, offer, favoriteIds);
          },
          onSaveForLater: (offer) {
            _confirmAndCreateGoal(
              context,
              offer,
              onConfirmed: () => Navigator.pop(sheetContext),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAndCreateGoal(
    BuildContext context,
    MarketOffer offer, {
    VoidCallback? onConfirmed,
  }) async {
    final existingGoal = _findExistingMarketplaceGoal(context, offer.id);
    if (existingGoal != null) {
      _showExistingGoalDialog(context, existingGoal);
      return;
    }

    final quantity = await _showMarketplaceQuantityDialog(
      context,
      offer,
      mode: _MarketplaceActionMode.goal,
    );
    if (!context.mounted || quantity == null) {
      return;
    }

    final authorized = await LocalSecurityService.authorizeIfEnabled(
      context,
      title: 'Creer un coffre',
      message:
          "Entrez votre PIN pour confirmer la creation d'un coffre pour ${offer.title} x$quantity.",
    );
    if (!context.mounted || !authorized) {
      return;
    }

    onConfirmed?.call();
    context.read<DashboardBloc>().add(
      CreateGoalFromMarketplaceOffer(offer, quantity: quantity),
    );
    _showSnackBar(
      context,
      "Un coffre a ete cree pour ${offer.title} x$quantity",
    );
  }

  TontineGoal? _findExistingMarketplaceGoal(
    BuildContext context,
    String offerId,
  ) {
    final state = context.read<DashboardBloc>().state;
    if (state is! DashboardLoaded) {
      return null;
    }

    for (final goal in state.goals) {
      if (goal.status == GoalStatus.active && goal.linkedOfferId == offerId) {
        return goal;
      }
    }
    return null;
  }

  Future<void> _showExistingGoalDialog(BuildContext context, TontineGoal goal) {
    final bloc = context.read<DashboardBloc>();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            "Coffre deja existant",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Text(
            "Un coffre actif existe deja pour cet article. Vous pouvez continuer a l'alimenter au lieu d'en creer un nouveau.",
            style: GoogleFonts.inter(height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Fermer"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: bloc,
                      child: GoalDetailScreen(goalId: goal.id),
                    ),
                  ),
                );
              },
              child: const Text("Voir le coffre"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmMarketplaceOrder(
    BuildContext context,
    MarketOffer offer,
    double availableBalance,
  ) async {
    final quantity = await _showMarketplaceQuantityDialog(
      context,
      offer,
      mode: _MarketplaceActionMode.order,
    );
    if (!context.mounted || quantity == null) {
      return;
    }

    final total = (offer.price ?? 0) * quantity;
    if (availableBalance < total) {
      _showSnackBar(
        context,
        "Solde insuffisant pour acheter ${offer.title} x$quantity.",
      );
      return;
    }

    final authorized = await LocalSecurityService.authorizeIfEnabled(
      context,
      title: 'Confirmer l’achat',
      message:
          "Entrez votre PIN pour confirmer l'achat de ${offer.title} x$quantity.",
    );
    if (!context.mounted || !authorized) {
      return;
    }

    context.read<DashboardBloc>().add(
      BuyMarketplaceOfferNow(offer, quantity: quantity),
    );
    _showSnackBar(
      context,
      "Commande enregistree pour ${offer.title} x$quantity",
    );
  }

  Future<int?> _showMarketplaceQuantityDialog(
    BuildContext context,
    MarketOffer offer, {
    required _MarketplaceActionMode mode,
  }) {
    int quantity = 1;
    final unitPrice = offer.price ?? 0;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final total = unitPrice * quantity;

            return AlertDialog(
              title: Text(
                mode == _MarketplaceActionMode.order
                    ? "Confirmer la commande"
                    : "Creer un coffre ?",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode == _MarketplaceActionMode.order
                        ? "Choisissez la quantite de ${offer.title} a commander."
                        : "Choisissez la quantite de ${offer.title} a preparer via un coffre.",
                    style: GoogleFonts.inter(height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _QuantityButton(
                        icon: Icons.remove_rounded,
                        onTap: quantity > 1
                            ? () => setState(() => quantity -= 1)
                            : null,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              "Quantite",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$quantity",
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _QuantityButton(
                        icon: Icons.add_rounded,
                        onTap: () => setState(() => quantity += 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ConfirmationLine(
                    label: "Prix unitaire",
                    value: "${formatFCFA(unitPrice)} F CFA",
                  ),
                  _ConfirmationLine(
                    label: "Montant total",
                    value: "${formatFCFA(total)} F CFA",
                  ),
                  if (mode == _MarketplaceActionMode.goal) ...[
                    _ConfirmationLine(
                      label: "Alimentation",
                      value: "Uniquement depuis le solde disponible",
                    ),
                    _ConfirmationLine(
                      label: "Retrait",
                      value: "Aucun retrait partiel",
                    ),
                    _ConfirmationLine(
                      label: "Cloture",
                      value: "Retour integral au disponible",
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, quantity),
                  child: Text(
                    mode == _MarketplaceActionMode.order
                        ? "Commander"
                        : "Creer le coffre",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConfirmationLine extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmationLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MarketplaceActionMode { order, goal }

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade100
              : AppTheme.primaryColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: onTap == null ? Colors.grey.shade400 : AppTheme.primaryColor,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
