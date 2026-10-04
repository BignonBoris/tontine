import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_detail_sheet.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_form_sheet.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:agent/features/clients/presentation/screens/agent_client_enrollment_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _service = AgentClientService();
  final _searchController = TextEditingController();
  String _filter = 'all';
  late Future<List<AgentClient>> _clientsFuture;

  @override
  void initState() {
    super.initState();
    _clientsFuture = _service.fetchMyClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _clientsFuture = _service.fetchMyClients(
        query: AgentInputRules.normalizePhone(_searchController.text),
        filter: _filter,
      );
    });
  }

  void _setFilter(String filter) {
    if (_filter == filter) {
      return;
    }
    setState(() {
      _filter = filter;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Rechercher un client',
            onPressed: _openSearchFiltersSheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Le formulaire de recherche a été déplacé dans un bottom sheet
            const SizedBox(height: 8),
            FutureBuilder<List<AgentClient>>(
              future: _clientsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: const AgentLoadingView(
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
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: AgentErrorView(
                      title: 'Clients indisponibles',
                      message: message,
                      onRetry: _reload,
                    ),
                  );
                }

                final clients = snapshot.data ?? const <AgentClient>[];
                if (clients.isEmpty) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: const AgentEmptyView(
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'clients_add_fab',
        onPressed: _openCreateClientSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  Future<void> _openCreateClientSheet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgentClientEnrollmentScreen()),
    );

    if (!mounted || result != true) {
      return;
    }

    _reload();
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

  void _openSearchFiltersSheet() {
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
                      Text(
                        'Rechercher et filtrer',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatusTag(
                        label: 'Tous',
                        selected: _filter == 'all',
                        onTap: () {
                          _setFilter('all');
                          setSheetState(() {});
                        },
                      ),
                      _StatusTag(
                        label: 'Tontine active',
                        selected: _filter == 'active',
                        onTap: () {
                          _setFilter('active');
                          setSheetState(() {});
                        },
                      ),
                      _StatusTag(
                        label: 'Sans tontine',
                        selected: _filter == 'inactive',
                        onTap: () {
                          _setFilter('inactive');
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recherche par téléphone',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  IntlPhoneField(
                    controller: _searchController,
                    initialCountryCode: 'BJ',
                    showCountryFlag: true,
                    showDropdownIcon: false,
                    disableLengthCheck: true,
                    onChanged: (_) => _reload(),
                    decoration: const InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: 'Ex. 01 23 45 67 89',
                      isDense: true,
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
}

class _StatusTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AgentAppTheme.accentColor
        : AgentAppTheme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.28)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
