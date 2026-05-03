import 'package:agent/core/storage/session_storage.dart';
import 'package:flutter/material.dart';

class AgentLogoutAction extends StatelessWidget {
  const AgentLogoutAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Deconnexion',
      onPressed: () => _confirmLogout(context),
      icon: const Icon(Icons.logout_rounded),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Se deconnecter'),
          content: const Text(
            "Voulez-vous vraiment fermer la session agent sur cet appareil ?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Deconnexion'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !context.mounted) {
      return;
    }

    await SessionStorage.clear();
    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
