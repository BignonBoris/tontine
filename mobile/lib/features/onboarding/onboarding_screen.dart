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
      title: 'Épargnez pour vos projets',
      description:
          'Construisez vos projets pas à pas grâce à une épargne régulière, simple et 100% sécurisée.',
    ),
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_2.png',
      title: 'La tontine comme moteur',
      description:
          'Suivez vos cotisations et vos tours de tontine à tout moment, en toute transparence.',
    ),
    _OnboardingPageData(
      imageAsset: 'assets/onboarding/onboarding_3.png',
      title: "Des coffres jusqu'au marketplace",
      description:
          'Concrétisez vos économies en projets et biens utiles directement sur le Marketplace.',
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
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
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
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _buildPageContent(_pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 14, 26, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => _buildDot(index),
                    ),
                  ),
                  _buildNextButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLastPage = _currentPage == _pages.length - 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 38,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isLastPage) {
              Navigator.pushReplacementNamed(context, '/auth_choice');
            } else {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(
              horizontal: isLastPage ? 16 : 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              gradient: isLastPage ? AppTheme.accentGradient : null,
              color: isLastPage ? null : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: isLastPage
                  ? null
                  : Border.all(color: Colors.white.withValues(alpha: 0.20)),
              boxShadow: isLastPage
                  ? [
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Row(
                key: ValueKey<bool>(isLastPage),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLastPage ? 'Commencer' : 'Suivant',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    isLastPage
                        ? Icons.arrow_forward_rounded
                        : Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.95, end: 1.0)
                              .animate(animation),
                          child: child,
                        ),
                      ),
                      child: Image.asset(
                        data.imageAsset,
                        key: ValueKey<String>(data.imageAsset),
                        height: imageHeight,
                        width: double.infinity,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 6 : 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: FittedBox(
                    key: ValueKey<String>(data.title),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      data.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                        fontSize: compact ? 22 : 25,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      data.description,
                      key: ValueKey<String>(data.description),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: compact ? 14 : 15,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.6,
                      ),
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 8),
      height: 8,
      width: isActive ? 28 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.accentColor
            : Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.accentColor.withValues(alpha: 0.40),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
