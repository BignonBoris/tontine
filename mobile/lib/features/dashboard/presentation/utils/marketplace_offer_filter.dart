import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';

List<MarketOffer> filterMarketplaceOffers({
  required List<MarketOffer> offers,
  String query = '',
  String? category,
}) {
  final normalizedQuery = query.trim().toLowerCase();

  return offers.where((offer) {
    final matchesCategory =
        category == null || category.isEmpty || offer.category == category;

    if (!matchesCategory) {
      return false;
    }

    if (normalizedQuery.isEmpty) {
      return true;
    }

    final haystack = [
      offer.title,
      offer.description,
      offer.category,
      offer.brand ?? '',
    ].join(' ').toLowerCase();

    return haystack.contains(normalizedQuery);
  }).toList();
}
