import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/provisioning/data/services/agent_provisioning_service.dart';
import 'package:agent/features/provisioning/domain/entities/agent_provisioning.dart';
import 'package:agent/features/provisioning/presentation/widgets/agent_provisioning_list_tile.dart';
import 'package:flutter/material.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = AgentProvisioningService();
  late Future<List<AgentProvisioning>> _provisioningsFuture;
  bool _isReversing = false;

  @override
  void initState() {
    super.initState();
    _provisioningsFuture = _service.fetchProvisionings();
  }

  void _reload() {
    setState(() {
      _provisioningsFuture = _service.fetchProvisionings();
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleReverse(AgentProvisioning provisioning) async {
    if (_isReversing) {
      return;
    }

    final reason = await _showReverseReasonDialog(provisioning);
    if (!mounted || reason == null) {
      return;
    }

    setState(() {
      _isReversing = true;
    });

    try {
      await _service.reverseProvisioning(
        provisioningId: provisioning.id,
        reason: reason,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Provisioning corrige avec succes.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isReversing = false;
        });
      }
    }
  }

  Future<String?> _showReverseReasonDialog(AgentProvisioning provisioning) async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Corriger le depot'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cette action va annuler le provisioning ${provisioning.reference} et contrepasser ses commissions.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Motif de correction',
                      hintText: 'Ex: mauvais client ou montant saisi',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Fermer'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = controller.text.trim();
                    if (reason.isEmpty) {
                      setDialogState(() {
                        errorText = 'Le motif est requis.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(reason);
                  },
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: const [AgentLogoutAction()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<AgentProvisioning>>(
          future: _provisioningsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 360,
                    child: AgentLoadingView(
                      message: 'Chargement des operations terrain...',
                    ),
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is ApiException
                  ? error.message
                  : "Impossible de charger l'historique agent.";
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 380,
                    child: AgentErrorView(
                      title: 'Historique indisponible',
                      message: message,
                      onRetry: _reload,
                    ),
                  ),
                ],
              );
            }

            final provisionings = snapshot.data ?? const <AgentProvisioning>[];
            if (provisionings.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 380,
                    child: AgentEmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'Aucune operation enregistree',
                      message:
                          "Les provisionings du terrain apparaitront ici apres synchronisation.",
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provisionings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return AgentProvisioningListTile(
                  provisioning: provisionings[index],
                  onReverse: _isReversing
                      ? null
                      : () => _handleReverse(provisionings[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
