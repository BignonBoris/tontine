import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:mobile/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:mobile/features/dashboard/presentation/widgets/dashboard_state_views.dart';
import 'package:mobile/features/dashboard/presentation/widgets/marketplace_offer_compact_card.dart';

class MarketplaceFavoritesScreen extends StatelessWidget {
  final List<MarketOffer> offers;
  final ValueChanged<MarketOffer> onOpenOffer;
  final ValueChanged<MarketOffer> onBuyNow;
  final ValueChanged<MarketOffer> onCreateGoal;

  const MarketplaceFavoritesScreen({
    super.key,
    required this.offers,
    required this.onOpenOffer,
    required this.onBuyNow,
    required this.onCreateGoal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          "Mes favoris",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardError) {
            return DashboardErrorView(
              title: state.title,
              message: state.message,
              inline: true,
              requiresReauthentication: state.requiresReauthentication,
            );
          }

          if (state is! DashboardLoaded) {
            return const DashboardLoadingView(
              label: "Chargement des favoris...",
              inline: true,
            );
          }

          final favoriteOffers = offers
              .where((offer) => state.favoriteOfferIds.contains(offer.id))
              .toList();

          if (favoriteOffers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 34,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "Aucun favori",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ajoutez des articles a vos favoris pour les retrouver rapidement.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 262,
            ),
            itemCount: favoriteOffers.length,
            itemBuilder: (context, index) {
              final offer = favoriteOffers[index];
              return MarketplaceOfferCompactCard(
                offer: offer,
                isFavorite: true,
                onTap: () => onOpenOffer(offer),
                onBuyNow: () => onBuyNow(offer),
                onToggleFavorite: () {
                  context.read<DashboardBloc>().add(
                    ToggleMarketplaceFavorite(offer.id),
                  );
                },
                onCreateGoal: () => onCreateGoal(offer),
              );
            },
          );
        },
      ),
    );
  }
}
