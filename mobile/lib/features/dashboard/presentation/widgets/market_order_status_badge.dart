import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/domain/entities/market_order.dart';

class MarketOrderStatusBadge extends StatelessWidget {
  final MarketOrderStatus status;

  const MarketOrderStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: palette.foreground,
        ),
      ),
    );
  }

  _StatusPalette _paletteFor(MarketOrderStatus status) {
    switch (status) {
      case MarketOrderStatus.pending:
        return const _StatusPalette(
          background: Color(0xFFFFF4E5),
          foreground: Color(0xFF8A5B00),
        );
      case MarketOrderStatus.confirmed:
        return const _StatusPalette(
          background: Color(0xFFE8EEF9),
          foreground: Color(0xFF1A237E),
        );
      case MarketOrderStatus.ready:
        return const _StatusPalette(
          background: Color(0xFFEAF6F4),
          foreground: Color(0xFF107C67),
        );
      case MarketOrderStatus.completed:
        return const _StatusPalette(
          background: Color(0xFFE8F5E9),
          foreground: Color(0xFF2E7D32),
        );
      case MarketOrderStatus.cancelled:
        return const _StatusPalette(
          background: Color(0xFFFFEBEE),
          foreground: Color(0xFFC62828),
        );
    }
  }
}

class _StatusPalette {
  final Color background;
  final Color foreground;

  const _StatusPalette({
    required this.background,
    required this.foreground,
  });
}
