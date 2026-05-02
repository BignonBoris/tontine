import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class MarketplaceCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onSelected;

  const MarketplaceCategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = ['Tous', ...categories];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final label = items[index];
          final category = label == 'Tous' ? null : label;
          final isSelected = selectedCategory == category;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withOpacity(0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _resolveIcon(label),
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : AppTheme.primaryColor.withOpacity(0.82),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _resolveIcon(String category) {
    if (category == 'Tous') {
      return Icons.grid_view_rounded;
    }
    switch (category.toUpperCase()) {
      case 'EQUIPEMENT':
        return Icons.home_work_outlined;
      case 'TRANSPORT':
        return Icons.two_wheeler_outlined;
      case 'MAISON':
        return Icons.chair_outlined;
      case 'TECH':
        return Icons.laptop_mac_outlined;
      case 'BUSINESS':
        return Icons.store_mall_directory_outlined;
      case 'ELECTRONIQUE':
        return Icons.tv_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }
}
