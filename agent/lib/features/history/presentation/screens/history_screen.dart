import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/provisioning/data/services/agent_provisioning_service.dart';
import 'package:agent/features/provisioning/domain/entities/agent_provisioning.dart';
import 'package:agent/features/provisioning/presentation/widgets/agent_provisioning_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  final bool isEmbedded;

  const HistoryScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _service = AgentProvisioningService();
  String _operationFilter = 'all';
  DateTimeRange? _dateRange;
  final _searchController = TextEditingController();
  final _dateController = TextEditingController();
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
  void dispose() {
    _searchController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void openFiltersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: SectionTitle(
                          title: 'Filtrer les operations',
                          subtitle: 'Affinez l’historique par date et par type.',
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: "Nom du client",
                      hintText: "Rechercher par nom...",
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _operationFilter,
                    decoration: const InputDecoration(
                      labelText: "Type d'operation",
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Toutes')),
                      DropdownMenuItem(value: 'validated', child: Text('Depots valides')),
                      DropdownMenuItem(value: 'pending_validation', child: Text('Depots en attente')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Depots annules')),
                      DropdownMenuItem(value: 'rejected', child: Text('Depots rejetes')),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        _operationFilter = value ?? 'all';
                      });
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    readOnly: true,
                    controller: _dateController,
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 1),
                        initialDateRange: _dateRange,
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          _dateRange = picked;
                          _dateController.text = '${DateFormat('dd/MM/yyyy').format(picked.start)} - ${DateFormat('dd/MM/yyyy').format(picked.end)}';
                        });
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: "Période",
                      hintText: "Choisir une période...",
                      isDense: true,
                      prefixIcon: const Icon(Icons.date_range_rounded),
                      suffixIcon: _dateRange != null
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 20),
                              onPressed: () {
                                setSheetState(() {
                                  _dateRange = null;
                                  _dateController.clear();
                                });
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
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
              children: const [
                SizedBox(
                  height: 380,
                  child: AgentEmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucune operation enregistree',
                    message: "Les provisionings du terrain apparaitront ici apres synchronisation.",
                  ),
                ),
              ],
            );
          }

          final hasSearch = _searchController.text.trim().isNotEmpty;
          final hasDate = _dateRange != null;
          final hasType = _operationFilter != 'all';
          
          final chips = <Widget>[];
          
          if (hasSearch) {
            chips.add(InputChip(
              label: Text('Nom: ${_searchController.text.trim()}', style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onDeleted: () {
                setState(() {
                  _searchController.clear();
                });
              },
            ));
          }
          
          if (hasDate) {
            chips.add(InputChip(
              label: Text(_dateController.text, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onDeleted: () {
                setState(() {
                  _dateRange = null;
                  _dateController.clear();
                });
              },
            ));
          }
          
          if (hasType) {
            final typeLabel = switch (_operationFilter) {
              'validated' => 'Validés',
              'pending_validation' => 'En attente',
              'cancelled' => 'Annulés',
              'rejected' => 'Rejetés',
              _ => '',
            };
            chips.add(InputChip(
              label: Text(typeLabel, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              onDeleted: () {
                setState(() {
                  _operationFilter = 'all';
                });
              },
            ));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${filteredProvisionings.length} opération${filteredProvisionings.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: -4,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredProvisionings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return AgentProvisioningListTile(
                      provisioning: filteredProvisionings[index],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Historique'),
        actions: [
          IconButton(
            onPressed: openFiltersSheet,
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: 'Filtrer les operations',
          ),
        ],
      ),
      body: body,
    );
  }

  List<AgentProvisioning> _applyFilters(List<AgentProvisioning> provisionings) {
    return provisionings.where((provisioning) {
      if (_operationFilter != 'all' && provisioning.status != _operationFilter) {
        return false;
      }

      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final clientName = provisioning.client?.displayName?.toLowerCase() ?? '';
        if (!clientName.contains(query)) {
          return false;
        }
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
