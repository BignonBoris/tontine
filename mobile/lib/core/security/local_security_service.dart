import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/core/utils/input_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalSecuritySettings {
  final bool pinEnabled;
  final bool biometricEnabled;

  const LocalSecuritySettings({
    required this.pinEnabled,
    required this.biometricEnabled,
  });
}

class LocalSecurityService {
  static const _pinEnabledKey = 'localSecurity.pinEnabled';
  static const _biometricEnabledKey = 'localSecurity.biometricEnabled';
  static const _pinHashKey = 'localSecurity.pinHash';

  static Future<LocalSecuritySettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalSecuritySettings(
      pinEnabled: prefs.getBool(_pinEnabledKey) ?? false,
      biometricEnabled: prefs.getBool(_biometricEnabledKey) ?? false,
    );
  }

  static Future<bool> hasAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final pinEnabled = prefs.getBool(_pinEnabledKey) ?? false;
    final pinHash = prefs.getString(_pinHashKey);
    return pinEnabled && pinHash != null && pinHash.isNotEmpty;
  }

  static Future<void> saveSettings({
    required bool pinEnabled,
    required bool biometricEnabled,
    String? pinCode,
    bool clearPin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinEnabledKey, pinEnabled);
    await prefs.setBool(_biometricEnabledKey, biometricEnabled);

    if (clearPin || !pinEnabled) {
      await prefs.remove(_pinHashKey);
      return;
    }

    if (pinCode != null && pinCode.isNotEmpty) {
      await prefs.setString(_pinHashKey, _hashPin(pinCode));
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinEnabledKey);
    await prefs.remove(_biometricEnabledKey);
    await prefs.remove(_pinHashKey);
  }

  static Future<bool> verifyPin(String pinCode) async {
    final prefs = await SharedPreferences.getInstance();
    final pinHash = prefs.getString(_pinHashKey);
    if (pinHash == null || pinHash.isEmpty) {
      return false;
    }
    return pinHash == _hashPin(pinCode);
  }

  static Future<bool> authorizeIfEnabled(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final enabled = await hasAppLockEnabled();
    if (!enabled) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _LocalPinDialog(title: title, message: message);
      },
    );
    return result ?? false;
  }

  static String _hashPin(String pinCode) {
    return sha256.convert(utf8.encode(pinCode)).toString();
  }
}

class _LocalPinDialog extends StatefulWidget {
  final String title;
  final String message;

  const _LocalPinDialog({required this.title, required this.message});

  @override
  State<_LocalPinDialog> createState() => _LocalPinDialogState();
}

class _LocalPinDialogState extends State<_LocalPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _error;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            inputFormatters: AppInputRules.pinFormatters,
            decoration: InputDecoration(
              labelText: 'Code PIN',
              errorText: _error,
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final isValid = await LocalSecurityService.verifyPin(
      _pinController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (!isValid) {
      setState(() {
        _isSubmitting = false;
        _error = 'PIN incorrect';
      });
      return;
    }

    Navigator.pop(context, true);
  }
}
