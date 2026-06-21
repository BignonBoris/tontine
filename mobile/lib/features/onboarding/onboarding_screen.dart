import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_1.png',
      title: 'Epargnez pour vos projets',
      description:
          "Transformez votre discipline d'epargne en avancee concrete sur vos objectifs personnels.",
    ),
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_2.png',
      title: 'La tontine comme moteur',
      description:
          'Votre cycle de tontine alimente une logique claire, suivie et lisible au quotidien.',
    ),
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_3.png',
      title: 'Des coffres jusqu au marketplace',
      description:
          'Reliez votre epargne a des biens utiles et a des projets reels, sans perdre le controle.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 18, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppTheme.brandIconAsset,
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VizioBox',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/auth_choice'),
                    child: Text(
                      'Passer',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _buildPageContent(_pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 16, 26, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => _buildDot(index),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        Navigator.pushReplacementNamed(context, '/auth_choice');
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Commencer'
                          : 'Suivant',
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

  Widget _buildPageContent(_OnboardingPageData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        final imageHeight = compact ? 340.0 : 460.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 4),
                    child: Image.asset(
                      data.imageAsset,
                      height: imageHeight,
                      width: double.infinity,
                      // fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                SizedBox(height: compact ? 6 : 10),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 24 : 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Text(
                    data.description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: compact ? 14 : 15,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: isActive ? 26 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.accentColor
            : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _OnboardingPageData {
  final String imageAsset;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.imageAsset,
    required this.title,
    required this.description,
  });
}
