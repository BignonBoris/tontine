import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class SpotlightStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final IconData icon;
  final String category;
  final BorderRadius borderRadius;
  final EdgeInsets padding;

  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.padding = const EdgeInsets.all(6),
  });
}

class VizioSpotlightOverlay extends StatefulWidget {
  final List<SpotlightStep> steps;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const VizioSpotlightOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<VizioSpotlightOverlay> createState() => _VizioSpotlightOverlayState();
}

class _VizioSpotlightOverlayState extends State<VizioSpotlightOverlay>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Rect? _targetRect;
  bool _isTransitioning = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTargetRect();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _updateTargetRect() async {
    if (!mounted || widget.steps.isEmpty) return;

    final currentStep = widget.steps[_currentIndex];
    final initialContext = currentStep.targetKey.currentContext;

    if (initialContext == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      if (currentStep.targetKey.currentContext == null) {
        _nextStep();
        return;
      }
    }

    final scrollContext = currentStep.targetKey.currentContext;
    if (scrollContext != null && scrollContext.mounted) {
      // Défilement automatique doux vers l'élément cible si nécessaire
      try {
        await Scrollable.ensureVisible(
          scrollContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.35,
        );
      } catch (_) {
        // Ignorer si pas dans un scrollable
      }
    }

    if (!mounted) return;

    final finalContext = currentStep.targetKey.currentContext;
    if (finalContext == null || !finalContext.mounted) return;

    final renderBox = finalContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final size = renderBox.size;
      final position = renderBox.localToGlobal(Offset.zero);

      final padding = currentStep.padding;
      final rect = Rect.fromLTWH(
        position.dx - padding.left,
        position.dy - padding.top,
        size.width + padding.horizontal,
        size.height + padding.vertical,
      );

      setState(() {
        _targetRect = rect;
        _isTransitioning = false;
      });
      _fadeController.forward(from: 0.0);
    }
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _currentIndex++;
        _isTransitioning = true;
      });
      _updateTargetRect();
    } else {
      _finishTour();
    }
  }

  void _previousStep() {
    HapticFeedback.selectionClick();
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isTransitioning = true;
      });
      _updateTargetRect();
    }
  }

  void _finishTour() {
    HapticFeedback.mediumImpact();
    widget.onFinish();
  }

  void _skipTour() {
    HapticFeedback.lightImpact();
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final currentStep = widget.steps[_currentIndex];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Voile assombrissant avec découpe nette du widget cible
            if (_targetRect != null)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    size: screenSize,
                    painter: _SpotlightPainter(
                      targetRect: _targetRect!,
                      borderRadius: currentStep.borderRadius,
                      pulseScale: _pulseAnimation.value,
                    ),
                  );
                },
              )
            else
              Container(color: const Color(0xDE0A192F)),

            // Bulle d'explication contextuelle positionnée dynamiquement
            if (_targetRect != null && !_isTransitioning)
              _buildTooltipCard(context, currentStep, screenSize),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipCard(
    BuildContext context,
    SpotlightStep step,
    Size screenSize,
  ) {
    final target = _targetRect!;
    final screenHeight = screenSize.height;

    // Déterminer si la bulle est au-dessus ou en-dessous du widget
    final spaceBelow = screenHeight - target.bottom;
    final placeBelow = spaceBelow > 230;

    final topPosition = placeBelow
        ? (target.bottom + 12).clamp(16.0, screenHeight - 260.0)
        : (target.top - 230).clamp(MediaQuery.of(context).padding.top + 10, screenHeight - 260.0);

    final isLast = _currentIndex == widget.steps.length - 1;

    return Positioned(
      top: topPosition,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F223D),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.accentColor.withValues(alpha: 0.40),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppTheme.accentDarkColor.withValues(alpha: 0.20),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne supérieure : Badge d'étape + Bouton fermer (X)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.accentColor,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${step.category} • ${_currentIndex + 1}/${widget.steps.length}',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: _skipTour,
                  tooltip: 'Quitter le guide',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Titre avec icône dorée
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    step.icon,
                    color: AppTheme.accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Description explicative
            Text(
              step.description,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Ligne d'actions : Points de progression + Boutons de navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Indicateurs de progression (dots)
                Row(
                  children: List.generate(
                    widget.steps.length,
                    (index) => Container(
                      width: index == _currentIndex ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: index == _currentIndex
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),

                // Boutons d'action
                Row(
                  children: [
                    if (_currentIndex > 0) ...[
                      TextButton(
                        onPressed: _previousStep,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          'Précédent',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentDarkColor
                                .withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: isLast ? _finishTour : _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLast ? 'C\'est parti !' : 'Suivant',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isLast
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final BorderRadius borderRadius;
  final double pulseScale;

  _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cutRRect = RRect.fromRectAndCorners(
      targetRect,
      topLeft: borderRadius.topLeft,
      topRight: borderRadius.topRight,
      bottomLeft: borderRadius.bottomLeft,
      bottomRight: borderRadius.bottomRight,
    );

    // Découpe compatible toutes plateformes (y compris Flutter Web HTML)
    // en utilisant la règle Even-Odd sur un seul tracé.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutRRect);

    final backdropPaint = Paint()
      ..color = const Color(0xE6061124)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, backdropPaint);

    // Halo lumineux doré (AppTheme.accentColor) autour de la zone sélectionnée
    final glowPaint = Paint()
      ..color = AppTheme.accentColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * pulseScale
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5.0);

    canvas.drawRRect(cutRRect, glowPaint);

    final borderPaint = Paint()
      ..color = AppTheme.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(cutRRect, borderPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseScale != pulseScale;
  }
}
