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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
