import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/widgets/auth_help_bottom_sheet.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 760;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 28,
                vertical: compact ? 12 : 20,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: compact ? 80 : 92,
                    height: compact ? 80 : 92,
                    padding: EdgeInsets.all(compact ? 12 : 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          AppTheme.accentColor.withValues(alpha: 0.18),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentDarkColor.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(AppTheme.brandIconAsset),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  Text(
                    "Prêt à concrétiser vos projets ?",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: compact ? 23 : 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Gérez vos tontines, votre épargne et vos projets utiles en toute sécurité.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 13.5 : 14.5,
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BrandPill(
                          background: AppTheme.accentColor.withValues(alpha: 0.20),
                          foreground: AppTheme.accentColor,
                          label: 'Tontine',
                          icon: Icons.repeat_rounded,
                        ),
                        _BrandPill(
                          background: AppTheme.secondaryColor.withValues(alpha: 0.20),
                          foreground: AppTheme.secondaryColor,
                          label: 'Coffres',
                          icon: Icons.savings_outlined,
                        ),
                        _BrandPill(
                          background: Colors.white.withValues(alpha: 0.15),
                          foreground: Colors.white,
                          label: 'Marketplace',
                          icon: Icons.storefront_outlined,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentDarkColor.withValues(alpha: 0.30),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Ouvrir un compte",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pushNamed(context, '/login'),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Se connecter",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => AuthHelpBottomSheet.show(context),
                        icon: Icon(
                          Icons.help_outline_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        label: Text(
                          "Besoin d'aide ?",
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Conforme aux normes de sécurité financière BCEAO',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  final Color background;
  final Color foreground;
  final String label;
  final IconData icon;

  const _BrandPill({
    required this.background,
    required this.foreground,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
