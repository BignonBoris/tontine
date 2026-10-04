import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientPinPad extends StatefulWidget {
  final void Function(String pin) onPinEntered;
  final int pinLength;
  final bool isError;
  final String? errorMessage;
  final bool isLoading;

  const ClientPinPad({
    super.key,
    required this.onPinEntered,
    this.pinLength = 4,
    this.isError = false,
    this.errorMessage,
    this.isLoading = false,
  });

  @override
  State<ClientPinPad> createState() => _ClientPinPadState();
}

class _ClientPinPadState extends State<ClientPinPad> {
  String _pin = '';

  void _onKeyPressed(String key) {
    if (widget.isLoading) return;
    if (_pin.length < widget.pinLength) {
      setState(() {
        _pin += key;
      });
      if (_pin.length == widget.pinLength) {
        widget.onPinEntered(_pin);
      }
    }
  }

  void _onBackspace() {
    if (widget.isLoading) return;
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  @override
  void didUpdateWidget(ClientPinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError && !oldWidget.isError) {
      setState(() {
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.pinLength,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _pin.length
                    ? (widget.isError ? Colors.red : const Color(0xFF165C30))
                    : const Color(0xFFE0E0E0),
                border: widget.isError
                    ? Border.all(color: Colors.red, width: 2)
                    : null,
              ),
            ),
          ),
        ),
        if (widget.isError && widget.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.errorMessage!,
            style: GoogleFonts.inter(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 32),
        // Numpad
        Opacity(
          opacity: widget.isLoading ? 0.5 : 1.0,
          child: IgnorePointer(
            ignoring: widget.isLoading,
            child: Column(
              children: [
                _buildRow(['1', '2', '3']),
                const SizedBox(height: 16),
                _buildRow(['4', '5', '6']),
                const SizedBox(height: 16),
                _buildRow(['7', '8', '9']),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const SizedBox(width: 72, height: 72),
                    _buildKey('0'),
                    _buildBackspace(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String key) {
    return InkWell(
      onTap: () => _onKeyPressed(key),
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF5F5F5),
        ),
        child: Text(
          key,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspace() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_outlined,
          size: 28,
          color: Color(0xFF1C1C1E),
        ),
      ),
    );
  }
}
