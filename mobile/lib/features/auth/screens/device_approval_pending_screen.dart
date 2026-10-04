import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/data/services/device_approval_service.dart';

class DeviceApprovalPendingScreen extends StatefulWidget {
  final String requestId;
  const DeviceApprovalPendingScreen({super.key, required this.requestId});
  @override
  State<DeviceApprovalPendingScreen> createState() => _DeviceApprovalPendingScreenState();
}

class _DeviceApprovalPendingScreenState extends State<DeviceApprovalPendingScreen> {
  final _service = DeviceApprovalService();
  Timer? _timer;
  String _message = 'En attente de l’autorisation de votre appareil déjà connecté…';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  Future<void> _check() async {
    if (_loading || !mounted) return;
    _loading = true;
    try {
      final request = await _service.status(widget.requestId);
      final status = '${request['status'] ?? ''}'.toLowerCase();
      if (!mounted) return;
      if (status == 'approved') {
        setState(() => _message = 'Connexion autorisée. Veuillez valider à nouveau le code OTP.');
        _timer?.cancel();
      } else if (status == 'rejected' || status == 'expired') {
        setState(() => _message = status == 'rejected' ? 'La connexion a été refusée.' : 'La demande a expiré.');
        _timer?.cancel();
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Impossible de vérifier la demande. Réessayez.');
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Autorisation requise')),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.devices_other_rounded, size: 64, color: AppTheme.primaryColor),
        const SizedBox(height: 20),
        Text(_message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (_loading) const CircularProgressIndicator(),
      ]),
    )),
  );
}
