import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/market_offer.dart';

class MarketOfferDetailSheet extends StatefulWidget {
  final List<MarketOffer> offers;
  final int initialIndex;
  final double availableBalance;
  final ValueChanged<MarketOffer> onBuyNow;
  final ValueChanged<MarketOffer> onToggleFavorite;
  final ValueChanged<MarketOffer> onSaveForLater;
  final List<String> favoriteOfferIds;

  const MarketOfferDetailSheet({
    super.key,
    required this.offers,
    required this.initialIndex,
    required this.availableBalance,
    required this.onBuyNow,
    required this.onToggleFavorite,
    required this.onSaveForLater,
    required this.favoriteOfferIds,
  });

  @override
  State<MarketOfferDetailSheet> createState() => _MarketOfferDetailSheetState();
}

class _MarketOfferDetailSheetState extends State<MarketOfferDetailSheet> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offers[currentIndex];
    final price = offer.price ?? 0;
    final canBuyNow = widget.availableBalance >= price;
    final isFavorite = widget.favoriteOfferIds.contains(offer.id);
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < widget.offers.length - 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Detail article",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Image.network(
                        offer.imageUrl,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 190,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SheetBadge(
                                label: offer.category,
                                backgroundColor:
                                    AppTheme.primaryColor.withOpacity(0.08),
                                foregroundColor: AppTheme.primaryColor,
                              ),
                              const Spacer(),
                              _SheetNavigationButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                enabled: hasPrevious,
                                tooltip: "Article precedent",
                                onTap: () {
                                  setState(() {
                                    currentIndex -= 1;
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              _SheetNavigationButton(
                                icon: Icons.arrow_forward_ios_rounded,
                                enabled: hasNext,
                                tooltip: "Article suivant",
                                onTap: () {
                                  setState(() {
                                    currentIndex += 1;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            offer.title,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          if ((offer.brand ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              "Marque: ${offer.brand}",
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Text(
                            "${formatFCFA(price)} F CFA",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.secondaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            offer.description.isEmpty
                                ? "Cet article peut etre achete immediatement avec votre solde disponible ou converti en coffre pour une epargne long terme."
                                : offer.description,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondaryColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6F8FE),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppTheme.accentColor,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Solde disponible: ${formatFCFA(widget.availableBalance)} F",
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SheetActionButton(
                      icon: Icons.flash_on_rounded,
                      label: "Acheter",
                      isEnabled: canBuyNow,
                      backgroundColor: const Color(0xFFE8EEF9),
                      foregroundColor: AppTheme.primaryColor,
                      onTap: () => widget.onBuyNow(offer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetActionButton(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: "Favori",
                      backgroundColor: const Color(0xFFFFF0F3),
                      foregroundColor: const Color(0xFFD81B60),
                      onTap: () => widget.onToggleFavorite(offer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetActionButton(
                      icon: Icons.savings_outlined,
                      label: "Coffre",
                      backgroundColor: const Color(0xFFEAF6F4),
                      foregroundColor: const Color(0xFF107C67),
                      onTap: () => widget.onSaveForLater(offer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isEnabled;
  final Color backgroundColor;
  final Color foregroundColor;

  const _SheetActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = isEnabled
        ? foregroundColor
        : AppTheme.textSecondaryColor.withOpacity(0.7);

    return Material(
      color: isEnabled ? backgroundColor : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: effectiveForeground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: effectiveForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _SheetBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _SheetNavigationButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final String tooltip;
  final VoidCallback onTap;

  const _SheetNavigationButton({
    required this.icon,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.primaryColor.withOpacity(0.06)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? AppTheme.primaryColor : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
