import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_detail_sheet.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_form_sheet.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:flutter/material.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _service = AgentClientService();
  final _searchController = TextEditingController();
  String _filter = 'all';
  DateTimeRange? _createdAtRange;
  bool _showSearchCard = false;
  late Future<List<AgentClient>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    _clientsFuture = _service.fetchMyClients().then(_applyDateFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _clientsFuture = _service
          .fetchMyClients(query: _searchController.text, filter: _filter)
          .then(_applyDateFilter);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Clients'),
        actions: [
          IconButton(
            onPressed: _toggleSearchCard,
            icon: Icon(
              _showSearchCard
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
            ),
            tooltip: _showSearchCard
                ? 'Masquer la recherche'
                : 'Rechercher un client',
          ),
          const AgentLogoutAction(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_showSearchCard) ...[
              SoftSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _reload(),
                      decoration: const InputDecoration(
                        labelText: 'Nom, telephone ou adresse',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filter,
                            decoration: const InputDecoration(
                              labelText: 'Statut tontine',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Tous'),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('Tontine active'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('Sans tontine'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _filter = value ?? 'all';
                              });
                              _reload();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.outlined(
                          onPressed: _pickCreatedAtRange,
                          tooltip: _createdAtRange == null
                              ? 'Filtrer par date'
                              : 'Modifier la periode',
                          icon: Icon(
                            Icons.date_range_rounded,
                            color: _createdAtRange == null
                                ? null
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton.outlined(
                          onPressed: _resetFilters,
                          tooltip: 'Reinitialiser les filtres',
                          icon: const Icon(Icons.restart_alt_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            FutureBuilder<List<AgentClient>>(
              future: _clientsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 260,
                    child: AgentLoadingView(
                      message: 'Chargement de votre portefeuille client...',
                    ),
                  );
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is ApiException
                      ? error.message
                      : 'Impossible de charger vos clients.';
                  return SizedBox(
                    height: 280,
                    child: AgentErrorView(
                      title: 'Clients indisponibles',
                      message: message,
                      onRetry: _reload,
                    ),
                  );
                }

                final clients = snapshot.data ?? const <AgentClient>[];
                if (clients.isEmpty) {
                  return const SizedBox(
                    height: 260,
                    child: AgentEmptyView(
                      icon: Icons.people_outline_rounded,
                      title: 'Aucun client dans votre portefeuille',
                      message:
                          "Ajoutez un client ou modifiez les filtres pour afficher d'autres resultats.",
                    ),
                  );
                }

                return Column(
                  children: clients
                      .map(
                        (client) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AgentClientListTile(
                            client: client,
                            trailing: IconButton(
                              onPressed: () => _openClientDetail(client),
                              icon: const Icon(Icons.arrow_forward_ios_rounded),
                            ),
                            onTap: () => _openClientDetail(client),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateClientSheet,
        label: const Text('Ajouter'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  Future<void> _pickCreatedAtRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _createdAtRange,
      locale: const Locale('fr', 'FR'),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _createdAtRange = picked;
    });
    _reload();
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _filter = 'all';
      _createdAtRange = null;
    });
    _reload();
  }

  void _toggleSearchCard() {
    setState(() {
      _showSearchCard = !_showSearchCard;
    });
  }

  Future<void> _openCreateClientSheet() async {
    final result = await showModalBottomSheet<AgentClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentClientFormSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    _reload();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Client cree avec succes.')));
  }

  Future<void> _openClientDetail(AgentClient client) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: AgentClientDetailSheet(clientId: client.id),
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  List<AgentClient> _applyDateFilter(List<AgentClient> clients) {
    final range = _createdAtRange;
    if (range == null) {
      return clients;
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

    return clients.where((client) {
      final createdAt = client.memberSince;
      if (createdAt == null) {
        return false;
      }
      return !createdAt.isBefore(start) && !createdAt.isAfter(end);
    }).toList();
  }
}
