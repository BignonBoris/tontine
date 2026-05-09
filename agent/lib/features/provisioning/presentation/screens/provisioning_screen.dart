import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:agent/features/clients/presentation/widgets/agent_start_tontine_sheet.dart';
import 'package:agent/features/provisioning/presentation/widgets/agent_deposit_sheet.dart';
import 'package:agent/features/withdrawals/presentation/widgets/agent_withdrawal_payment_sheet.dart';
import 'package:flutter/material.dart';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final _clientService = AgentClientService();
  final _clientSearchController = TextEditingController();

  List<AgentClient> _searchResults = const [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchClients(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final clients = await _clientService.searchClients(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = clients;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Operation'),
        actions: [
          IconButton(
            onPressed: _openWithdrawalPaymentSheet,
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Payer un retrait',
          ),
          const AgentLogoutAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Rechercher un client',
                  subtitle:
                      "Vous pouvez deposer pour tout client du systeme, meme s'il n'a pas ete inscrit par vous.",
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _clientSearchController,
                  onChanged: _searchClients,
                  decoration: InputDecoration(
                    labelText: 'Nom, telephone ou code client',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_clientSearchController.text.trim().isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _clientSearchController.clear();
                                    setState(() {
                                      _searchResults = const [];
                                      _searchError = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_searchError != null)
            SizedBox(
              height: 220,
              child: AgentErrorView(
                title: 'Recherche client impossible',
                message: _searchError!,
                onRetry: () => _searchClients(_clientSearchController.text),
              ),
            )
          else if (_clientSearchController.text.trim().isNotEmpty &&
              !_isSearching)
            _searchResults.isEmpty
                ? const SizedBox(
                    height: 220,
                    child: AgentEmptyView(
                      icon: Icons.person_off_outlined,
                      title: 'Aucun client correspondant',
                      message:
                          "Affinez la recherche ou verifiez que le client est bien actif.",
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Clients trouves',
                        subtitle:
                            "Choisissez le bon client avant d'enregistrer le depot.",
                      ),
                      const SizedBox(height: 12),
                      ..._searchResults.map(
                        (client) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AgentClientListTile(
                            client: client,
                            trailing: TextButton(
                              onPressed: () => _handleClientSelection(client),
                              child: const Text('Choisir'),
                            ),
                            onTap: () => _handleClientSelection(client),
                          ),
                        ),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDepositSheet(AgentClient client) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentDepositSheet(client: client),
    );

    if (!mounted || result != true) {
      return;
    }

    _clientSearchController.clear();
    setState(() {
      _searchResults = const [];
      _searchError = null;
    });
    _showMessage('Depot terrain enregistre avec succes.');
  }

  Future<void> _openWithdrawalPaymentSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentWithdrawalPaymentSheet(),
    );

    if (!mounted || result != true) {
      return;
    }

    _showMessage('Retrait client paye avec succes.');
  }

  Future<void> _handleClientSelection(AgentClient client) async {
    if (client.hasActiveTontine) {
      await _openDepositSheet(client);
      return;
    }

    final result = await showModalBottomSheet<AgentClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentStartTontineSheet(client: client),
    );

    if (!mounted || result == null) {
      return;
    }

    _clientSearchController.clear();
    setState(() {
      _searchResults = const [];
      _searchError = null;
    });
    _showMessage('Tontine demarree avec succes.');
  }
}
