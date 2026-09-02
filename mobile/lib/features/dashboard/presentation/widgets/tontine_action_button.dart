import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class TontineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? iconColor;
  final Color? textColor;
  final bool isPrimary;
  final VoidCallback onTap;

  const TontineActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.color,
    this.gradient,
    this.backgroundColor,
    this.borderColor,
    this.iconColor,
    this.textColor,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? (isPrimary ? Colors.white : (color ?? AppTheme.primaryColor));
    final effectiveTextColor = textColor ?? (isPrimary ? Colors.white : (color ?? AppTheme.primaryColor));
    final effectiveBgColor = backgroundColor ?? (gradient == null ? (color?.withValues(alpha: 0.1) ?? Colors.white) : null);
    final effectiveBorderColor = borderColor ?? (gradient == null ? (color?.withValues(alpha: 0.28) ?? AppTheme.borderColor) : null);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: gradient,
              color: effectiveBgColor,
              borderRadius: BorderRadius.circular(16),
              border: effectiveBorderColor != null
                  ? Border.all(color: effectiveBorderColor, width: 1.2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: (isPrimary
                          ? AppTheme.accentDarkColor
                          : AppTheme.primaryColor)
                      .withValues(alpha: isPrimary ? 0.24 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: effectiveIconColor, size: 19),
                const SizedBox(width: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: effectiveTextColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.1,
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
