import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
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
  bool _showFilters = false;
  String _operationFilter = 'all';
  DateTimeRange? _dateRange;
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Historique'),
        actions: [
          IconButton(
            onPressed: _toggleFilters,
            icon: Icon(
              _showFilters ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
            ),
            tooltip: _showFilters
                ? 'Masquer les filtres'
                : 'Filtrer les operations',
          ),
          const AgentLogoutAction(),
        ],
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
            final filteredProvisionings = _applyFilters(provisionings);
            if (filteredProvisionings.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_showFilters) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _buildFiltersCard(context),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const SizedBox(
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
              padding: EdgeInsets.fromLTRB(
                20,
                _showFilters ? 0 : 20,
                20,
                20,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filteredProvisionings.length + (_showFilters ? 1 : 0),
              separatorBuilder: (_, index) => SizedBox(
                height: index == 0 && _showFilters ? 18 : 12,
              ),
              itemBuilder: (context, index) {
                if (_showFilters) {
                  if (index == 0) {
                    return _buildFiltersCard(context);
                  }
                  final provisioning = filteredProvisionings[index - 1];
                  return AgentProvisioningListTile(provisioning: provisioning);
                }

                return AgentProvisioningListTile(
                  provisioning: filteredProvisionings[index],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersCard(BuildContext context) {
    return SoftSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            title: 'Filtrer les operations',
            subtitle: 'Affinez l’historique par date et par type.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _operationFilter,
            decoration: const InputDecoration(
              labelText: "Type d'operation",
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Toutes')),
              DropdownMenuItem(value: 'validated', child: Text('Depots valides')),
              DropdownMenuItem(
                value: 'pending_validation',
                child: Text('Depots en attente'),
              ),
              DropdownMenuItem(value: 'cancelled', child: Text('Depots annules')),
              DropdownMenuItem(value: 'rejected', child: Text('Depots rejetes')),
            ],
            onChanged: (value) {
              setState(() {
                _operationFilter = value ?? 'all';
              });
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    _dateRange == null
                        ? 'Choisir une periode'
                        : 'Periode selectionnee',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                onPressed: _resetFilters,
                tooltip: 'Reinitialiser les filtres',
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      locale: const Locale('fr', 'FR'),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _dateRange = picked;
    });
  }

  void _resetFilters() {
    setState(() {
      _operationFilter = 'all';
      _dateRange = null;
    });
  }

  List<AgentProvisioning> _applyFilters(List<AgentProvisioning> provisionings) {
    return provisionings.where((provisioning) {
      if (_operationFilter != 'all' && provisioning.status != _operationFilter) {
        return false;
      }

      final range = _dateRange;
      if (range == null) {
        return true;
      }

      final operationDate = provisioning.createdAt ?? provisioning.validatedAt;
      if (operationDate == null) {
        return false;
      }

      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      );

      return !operationDate.isBefore(start) && !operationDate.isAfter(end);
    }).toList();
  }
}
