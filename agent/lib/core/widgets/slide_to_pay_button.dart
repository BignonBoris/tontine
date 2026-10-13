import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Un bouton "glisser pour payer" anti-clic accidentel.
/// L'agent doit faire glisser le curseur jusqu'à la fin (>90%)
/// pour déclencher l'action de paiement.
class SlideToPayButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final bool isLoading;
  final String label;
  final Color? trackColor;
  final Color? thumbColor;

  const SlideToPayButton({
    super.key,
    required this.onConfirmed,
    this.isLoading = false,
    this.label = 'Glisser pour payer',
    this.trackColor,
    this.thumbColor,
  });

  @override
  State<SlideToPayButton> createState() => _SlideToPayButtonState();
}

class _SlideToPayButtonState extends State<SlideToPayButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _completed = false;

  static const double _thumbSize = 58.0;
  static const double _trackHeight = 64.0;
  static const double _threshold = 0.90;

  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  double _dragStartPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _resetAnimation = CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOut,
    );
    _resetAnimation.addListener(() {
      if (mounted) {
        setState(() {
          _dragPosition = _resetAnimation.value * _dragStartPosition;
        });
      }
    });
    _resetController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dragStartPosition = 0;
      }
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (_completed || widget.isLoading) return;
    setState(() {
      _dragPosition =
          (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onDragEnd(double maxDrag) {
    if (_completed || widget.isLoading) return;
    final progress = _dragPosition / maxDrag;
    if (progress >= _threshold) {
      setState(() => _completed = true);
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
    } else {
      // Retour animé à la position initiale
      _dragStartPosition = _dragPosition;
      _resetController.forward(from: 1.0);
      HapticFeedback.lightImpact();
    }
  }

  @override
  void didUpdateWidget(SlideToPayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset si le chargement est terminé (ex: erreur API)
    if (oldWidget.isLoading && !widget.isLoading && !_completed) {
      setState(() => _dragPosition = 0.0);
    }
    // Si c'était completed et qu'on remet isLoading=false après erreur, reset
    if (_completed && !widget.isLoading) {
      setState(() => _completed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = widget.trackColor ?? const Color(0xFF165C30);
    final thumbColor = widget.thumbColor ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _thumbSize - 8;
        final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: trackColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(_trackHeight / 2),
            border: Border.all(
              color: trackColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Fond de progression
              AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                width: _thumbSize + 8 + _dragPosition,
                height: _trackHeight,
                decoration: BoxDecoration(
                  color: trackColor.withOpacity(0.18 + progress * 0.22),
                  borderRadius: BorderRadius.circular(_trackHeight / 2),
                ),
              ),

              // Label centré
              Center(
                child: AnimatedOpacity(
                  opacity: (1.0 - progress * 1.8).clamp(0.0, 1.0),
                  duration: const Duration(milliseconds: 100),
                  child: widget.isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: trackColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Traitement en cours...',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: trackColor,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_right_rounded,
                              color: trackColor.withOpacity(0.4),
                              size: 20,
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: trackColor.withOpacity(0.65),
                              size: 20,
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: trackColor,
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.label,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: trackColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Curseur (thumb)
              if (!widget.isLoading)
                Positioned(
                  left: 4 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                    onHorizontalDragEnd: (_) => _onDragEnd(maxDrag),
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: trackColor,
                        boxShadow: [
                          BoxShadow(
                            color: trackColor.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: progress >= _threshold
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 26,
                            )
                          : const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
