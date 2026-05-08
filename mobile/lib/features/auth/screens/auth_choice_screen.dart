import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 118,
                height: 118,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      AppTheme.accentColor.withValues(alpha: 0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentDarkColor.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Image.asset(AppTheme.brandIconAsset),
              ),
              const SizedBox(height: 28),
              Text(
                "Pret a construire votre prochain projet ?",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Avec VizioBox, votre tontine alimente vos objectifs, vos coffres et vos achats utiles sans alourdir votre parcours.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.accentColor.withValues(alpha: 0.30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentDarkColor.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _BrandPill(
                      background: AppTheme.primaryColor.withValues(alpha: 0.09),
                      foreground: AppTheme.primaryColor,
                      label: 'Tontine',
                    ),
                    _BrandPill(
                      background: AppTheme.secondaryColor.withValues(
                        alpha: 0.14,
                      ),
                      foreground: AppTheme.secondaryVariantColor,
                      label: 'Coffres',
                    ),
                    _BrandPill(
                      background: AppTheme.accentColor.withValues(alpha: 0.18),
                      foreground: AppTheme.accentDarkColor,
                      label: 'Marketplace',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Ouvrir un compte"),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: OutlinedButton.styleFrom(
                    // foregroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.accentColor,
                    side: BorderSide(
                      color: AppTheme.accentColor.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: const Text("Se connecter"),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {},
                child: Text(
                  "Besoin d'aide ?",
                  style: GoogleFonts.inter(
                    // color: AppTheme.accentDarkColor,
                    color: Colors.white,
                    decoration: TextDecoration.underline,
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

class _BrandPill extends StatelessWidget {
  final Color background;
  final Color foreground;
  final String label;

  const _BrandPill({
    required this.background,
    required this.foreground,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        softWrap: false,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
