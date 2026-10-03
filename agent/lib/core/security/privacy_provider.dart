import 'package:flutter/material.dart';

/// A lightweight [InheritedWidget]-based privacy mode controller.
///
/// Manages the global toggle between "visible" and "masked" states
/// for sensitive data displayed in the Agent UI.
///
/// Usage:
/// ```dart
/// // Wrap root with PrivacyProvider
/// PrivacyProvider(child: YourAppWidget())
///
/// // Read state
/// final isPrivate = PrivacyProvider.of(context).isPrivate;
///
/// // Toggle
/// PrivacyProvider.of(context).toggle();
/// ```
class PrivacyProvider extends StatefulWidget {
  final Widget child;

  const PrivacyProvider({super.key, required this.child});

  /// Returns the [PrivacyState] from the nearest [PrivacyProvider] ancestor.
  static PrivacyState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_PrivacyScope>();
    assert(scope != null, 'No PrivacyProvider found in context.');
    return scope!.state;
  }

  @override
  State<PrivacyProvider> createState() => _PrivacyProviderState();
}

/// Public interface exposing privacy mode state and controls.
abstract class PrivacyState {
  bool get isPrivate;
  void toggle();
  void setPrivate(bool value);
}

class _PrivacyProviderState extends State<PrivacyProvider> implements PrivacyState {
  // Default: privacy mode is ON (data masked) for security
  bool _isPrivate = true;

  @override
  bool get isPrivate => _isPrivate;

  @override
  void toggle() {
    setState(() {
      _isPrivate = !_isPrivate;
    });
  }

  @override
  void setPrivate(bool value) {
    if (_isPrivate != value) {
      setState(() {
        _isPrivate = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PrivacyScope(
      state: this,
      isPrivate: _isPrivate,
      child: widget.child,
    );
  }
}

class _PrivacyScope extends InheritedWidget {
  final PrivacyState state;
  final bool isPrivate;

  const _PrivacyScope({
    required this.state,
    required this.isPrivate,
    required super.child,
  });

  @override
  bool updateShouldNotify(_PrivacyScope oldWidget) {
    return oldWidget.isPrivate != isPrivate;
  }
}

/// A convenience widget that shows an eye icon button to toggle privacy mode.
///
/// Place it in an AppBar or on any screen where privacy mode should be toggled.
class PrivacyToggleButton extends StatelessWidget {
  final Color? color;
  final double? size;

  const PrivacyToggleButton({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final privacy = PrivacyProvider.of(context);
    return IconButton(
      tooltip: privacy.isPrivate ? 'Afficher les montants' : 'Masquer les montants',
      iconSize: size,
      color: color,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Icon(
          privacy.isPrivate
              ? Icons.visibility_off_rounded
              : Icons.visibility_rounded,
          key: ValueKey(privacy.isPrivate),
          size: size,
          color: color,
        ),
      ),
      onPressed: privacy.toggle,
    );
  }
}
