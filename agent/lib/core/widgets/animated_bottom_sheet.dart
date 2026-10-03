import 'package:flutter/material.dart';

/// Un wrapper pour tous les bottom sheets de l'application.
/// Fournit une animation de fermeture fluide (descente + fondu)
/// quand on appelle [AnimatedBottomSheet.closeOf(context)].
class AnimatedBottomSheet extends StatefulWidget {
  final Widget child;

  const AnimatedBottomSheet({super.key, required this.child});

  /// Ferme le bottom sheet avec l'animation de descente + fondu.
  /// À utiliser à la place de [Navigator.pop] dans tous les bottom sheets.
  static Future<void> closeOf(BuildContext context, [dynamic result]) async {
    final state =
        context.findAncestorStateOfType<_AnimatedBottomSheetState>();
    if (state != null) {
      await state._animateAndClose(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  @override
  State<AnimatedBottomSheet> createState() => _AnimatedBottomSheetState();
}

class _AnimatedBottomSheetState extends State<AnimatedBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));

    _fadeAnimation = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateAndClose([dynamic result]) async {
    await _controller.forward();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
