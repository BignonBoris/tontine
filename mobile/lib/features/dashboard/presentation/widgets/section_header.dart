import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onActionPressed;
  final String actionLabel;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    required this.onActionPressed,
    this.actionLabel = 'Faire un depot',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        TextButton.icon(
          onPressed: onActionPressed,
          icon: Icon(
            icon ?? Icons.add_circle_outline,
            size: 18,
            color: AppTheme.accentColor,
          ),
          label: Text(
            actionLabel,
            style: GoogleFonts.inter(
              color: AppTheme.accentDarkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
