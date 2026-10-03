import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:agent/core/utils/input_rules.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/animated_bottom_sheet.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_client_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AgentClientSearchSheet extends StatefulWidget {
  const AgentClientSearchSheet({super.key});

  @override
  State<AgentClientSearchSheet> createState() => _AgentClientSearchSheetState();
}

class _AgentClientSearchSheetState extends State<AgentClientSearchSheet> {
  final _clientService = AgentClientService();
  final _clientSearchController = TextEditingController();

  List<AgentClient> _searchResults = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;
  String _searchType = 'phone';

  @override
  void dispose() {
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchClients() async {
    final query = _searchType == 'phone'
        ? AgentInputRules.normalizePhone(_clientSearchController.text)
        : _clientSearchController.text.trim();
        
    if (query.isEmpty) {
      setState(() {
        _searchResults = const [];
        _searchError = null;
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    if (_searchType == 'phone' && query.length != 10) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searchError = null;
        _hasSearched = false;
        _isSearching = false;
      });
      _showMessage('Saisissez un numéro complet à 10 chiffres.');
      return;
    }
    
    if (_searchType == 'name' && query.length < 2) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searchError = null;
        _hasSearched = false;
        _isSearching = false;
      });
      _showMessage('Saisissez au moins 2 caractères pour la recherche.');
      return;
    }

    setState(() {
      _hasSearched = true;
      _isSearching = true;
      _searchError = null;
      _searchResults = const [];
    });

    try {
      final clients = await _clientService.searchClients(query, type: _searchType);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return AnimatedBottomSheet(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: bottomInset > 0 ? bottomInset + 20 : 20,
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
                  title: 'Rechercher un client',
                  subtitle: 'Saisissez les informations pour trouver le client.',
                ),
              ),
              IconButton(
                onPressed: () => AnimatedBottomSheet.closeOf(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AgentAppTheme.primaryColor,
                selectedForegroundColor: Colors.white,
                foregroundColor: AgentAppTheme.primaryColor,
                side: const BorderSide(color: Color(0xFF082040), width: 1.2),
              ),
              segments: const [
                ButtonSegment(value: 'phone', label: Text('Numéro'), icon: Icon(Icons.phone_rounded, size: 18)),
                ButtonSegment(value: 'name', label: Text('Nom'), icon: Icon(Icons.person_rounded, size: 18)),
              ],
              selected: {_searchType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _searchType = newSelection.first;
                  _clientSearchController.clear();
                  _searchResults = const [];
                  _searchError = null;
                  _hasSearched = false;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_searchType == 'phone')
            IntlPhoneField(
              controller: _clientSearchController,
              initialCountryCode: 'BJ',
              showCountryFlag: true,
              showDropdownIcon: false,
              disableLengthCheck: true,
              onChanged: (_) {
                if (!_hasSearched && _searchResults.isEmpty && _searchError == null) return;
                setState(() {
                  _hasSearched = false;
                  _searchResults = const [];
                  _searchError = null;
                });
              },
              decoration: InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: 'Ex. 01 23 45 67 89',
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
                                _hasSearched = false;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null),
              ),
            )
          else
            TextFormField(
              controller: _clientSearchController,
              onChanged: (_) {
                if (!_hasSearched && _searchResults.isEmpty && _searchError == null) return;
                setState(() {
                  _hasSearched = false;
                  _searchResults = const [];
                  _searchError = null;
                });
              },
              decoration: InputDecoration(
                labelText: 'Nom du client',
                hintText: 'Ex. Jean',
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
                                _hasSearched = false;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSearching ? null : _searchClients,
              icon: _isSearching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(_isSearching ? 'Recherche...' : 'Rechercher'),
            ),
          ),
          if (_hasSearched) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Flexible(
              child: _buildSearchResults(),
            ),
          ] else
             const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchError != null) {
      return AgentErrorView(
        title: 'Recherche impossible',
        message: _searchError!,
        onRetry: _searchClients,
      );
    }

    if (_searchResults.isEmpty) {
      return const AgentEmptyView(
        icon: Icons.person_off_outlined,
        title: 'Aucun client trouve',
        message: 'Verifiez le numero ou creez un nouveau client.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final client = _searchResults[index];
        return AgentClientListTile(
          client: client,
          trailing: TextButton(
            onPressed: () => AnimatedBottomSheet.closeOf(context, client),
            child: const Text('Choisir'),
          ),
          onTap: () => AnimatedBottomSheet.closeOf(context, client),
        );
      },
    );
  }
}
