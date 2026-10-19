import 'package:flutter/material.dart';
import 'package:agent/core/services/update_service.dart';

/// Dialog de mise à jour affiché lorsqu'une nouvelle version est disponible.
///
/// - [result.isMandatory] = true → dialog non dismissable, bloque l'app
/// - [result.isMandatory] = false → bouton "Plus tard" disponible
class UpdateDialog extends StatefulWidget {
  final UpdateCheckResult result;

  const UpdateDialog({super.key, required this.result});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0.0;
  String? _errorMessage;

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _startUpdate() async {
    final downloadUrl = widget.result.serverVersion?.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      setState(() => _errorMessage = 'Lien de téléchargement indisponible.');
      return;
    }

    setState(() {
      _phase = _Phase.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    final path = await UpdateService.instance.downloadApk(
      downloadUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;
    if (path == null) {
      setState(() {
        _phase = _Phase.idle;
        _errorMessage = 'Échec du téléchargement. Vérifiez votre connexion.';
      });
      return;
    }

    setState(() => _phase = _Phase.installing);
    await UpdateService.instance.installApk(path);

    // Après le lancement de l'installer, on repasse en idle
    // (l'utilisateur peut annuler dans l'installer système)
    if (mounted) {
      setState(() => _phase = _Phase.idle);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final serverVersion = widget.result.serverVersion;
    final isMandatory = widget.result.isMandatory;
    final theme = Theme.of(context);

    return PopScope(
      // Empêcher le retour arrière si obligatoire ou pendant le téléchargement
      canPop: !isMandatory && _phase == _Phase.idle,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.system_update_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMandatory ? 'Mise à jour requise' : 'Mise à jour disponible',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (serverVersion != null)
                    Text(
                      'Version ${serverVersion.version}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // Badge obligatoire
            if (isMandatory)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚠️  Mise à jour obligatoire',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (isMandatory) const SizedBox(height: 10),

            // Notes de version
            if (serverVersion?.releaseNotes.isNotEmpty == true) ...[
              Text(
                'Nouveautés :',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                serverVersion!.releaseNotes,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],

            // Barre de progression
            if (_phase == _Phase.downloading) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: _progress,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                'Téléchargement... ${(_progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],

            if (_phase == _Phase.installing) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Installation en cours...'),
                ],
              ),
            ],

            // Message d'erreur
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Bouton "Plus tard" — uniquement si non obligatoire et pas en cours
          if (!isMandatory && _phase == _Phase.idle)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Plus tard'),
            ),

          // Bouton principal
          if (_phase == _Phase.idle)
            ElevatedButton.icon(
              onPressed: _startUpdate,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Mettre à jour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Phase { idle, downloading, installing }
