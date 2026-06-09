import 'package:flutter/material.dart';
import 'package:mobile/features/groups/presentation/screens/group_invitation_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class GroupQrScannerScreen extends StatefulWidget {
  const GroupQrScannerScreen({super.key});

  @override
  State<GroupQrScannerScreen> createState() => _GroupQrScannerScreenState();
}

class _GroupQrScannerScreenState extends State<GroupQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _isHandlingScan = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un QR groupe')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(
                  'Scannez le QR code partage par l agent pour ouvrir l invitation du groupe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isHandlingScan || capture.barcodes.isEmpty) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue?.trim();
    final token = _extractInvitationToken(rawValue);
    if (token == null) {
      _showMessage('Ce QR code ne correspond pas a une invitation de groupe.');
      return;
    }

    _isHandlingScan = true;
    await _controller.stop();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GroupInvitationScreen(token: token),
      ),
    );
  }

  String? _extractInvitationToken(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    final directSegments = rawValue.split('/');
    if (directSegments.length == 2 && directSegments.first == 'group-invitations') {
      return directSegments.last.isEmpty ? null : directSegments.last;
    }

    final uri = Uri.tryParse(rawValue);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    final invitationIndex = segments.indexOf('group-invitations');
    if (invitationIndex == -1 || invitationIndex + 1 >= segments.length) {
      return null;
    }

    final token = segments[invitationIndex + 1].trim();
    return token.isEmpty ? null : token;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
