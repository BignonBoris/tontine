import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';
import 'package:mobile/features/dashboard/presentation/utils/marketplace_offer_filter.dart';

class MarketplaceSearchDelegate extends SearchDelegate<MarketOffer?> {
  final List<MarketOffer> offers;

  MarketplaceSearchDelegate({required this.offers});

  @override
  String get searchFieldLabel => "Rechercher un article";

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _ResultsList(
      offers: filterMarketplaceOffers(offers: offers, query: query),
      onSelect: (offer) => close(context, offer),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = filterMarketplaceOffers(offers: offers, query: query);
    return _ResultsList(
      offers: filtered,
      onSelect: (offer) => close(context, offer),
      emptyLabel: query.isEmpty
          ? "Recherchez par nom, marque ou categorie."
          : "Aucun article ne correspond a votre recherche.",
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<MarketOffer> offers;
  final ValueChanged<MarketOffer> onSelect;
  final String? emptyLabel;

  const _ResultsList({
    required this.offers,
    required this.onSelect,
    this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          emptyLabel ?? "Aucun resultat",
          style: GoogleFonts.inter(color: AppTheme.textSecondaryColor),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: offers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final offer = offers[index];
        return ListTile(
          onTap: () => onSelect(offer),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          tileColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              offer.imageUrl,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 54,
                height: 54,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
          title: Text(
            offer.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            offer.category,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          trailing: const Icon(
            Icons.north_east_rounded,
            color: AppTheme.primaryColor,
          ),
        );
      },
    );
  }
}
