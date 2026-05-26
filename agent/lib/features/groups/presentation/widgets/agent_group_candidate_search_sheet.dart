import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/features/groups/data/services/agent_group_service.dart';
import 'package:agent/features/groups/domain/entities/agent_group_member.dart';
import 'package:flutter/material.dart';

class AgentGroupCandidateSearchSheet extends StatefulWidget {
  final String groupId;

  const AgentGroupCandidateSearchSheet({super.key, required this.groupId});

  @override
  State<AgentGroupCandidateSearchSheet> createState() =>
      _AgentGroupCandidateSearchSheetState();
}

class _AgentGroupCandidateSearchSheetState
    extends State<AgentGroupCandidateSearchSheet> {
  final _service = AgentGroupService();
  final _searchController = TextEditingController();
  List<AgentGroupCandidate> _candidates = const [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ajouter un participant',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _searchCandidates,
              decoration: InputDecoration(
                labelText: 'Nom, telephone ou adresse',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 420,
              child: Builder(
                builder: (context) {
                  if (_errorMessage != null) {
                    return AgentErrorView(
                      title: 'Recherche impossible',
                      message: _errorMessage!,
                      onRetry: () => _searchCandidates(_searchController.text),
                    );
                  }
                  if (_searchController.text.trim().isEmpty) {
                    return const AgentEmptyView(
                      icon: Icons.person_search_rounded,
                      title: 'Lancez une recherche',
                      message:
                          'Cherchez un client existant pour l ajouter au groupe.',
                    );
                  }
                  if (_isSearching) {
                    return const AgentLoadingView(
                      message: 'Recherche des candidats en cours...',
                    );
                  }
                  if (_candidates.isEmpty) {
                    return const AgentEmptyView(
                      icon: Icons.person_off_outlined,
                      title: 'Aucun candidat',
                      message:
                          'Aucun client actif disponible ne correspond a cette recherche.',
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: _candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final candidate = _candidates[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary.withValues(
                                      alpha: 0.10,
                                    ),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(Icons.person_add_alt_1_rounded),
                          ),
                          title: Text(candidate.displayName),
                          subtitle: Text(
                            [
                              '${candidate.phoneNumber}${candidate.address?.isNotEmpty == true ? ' • ${candidate.address}' : ''}',
                              candidate.canBeRanked &&
                                      candidate.minimumEligibleTurn != null
                                  ? 'Rang recommande: a partir du tour ${candidate.minimumEligibleTurn}'
                                  : 'Capacite insuffisante pour un rang recommande actuellement',
                            ].join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: TextButton(
                            onPressed: () => Navigator.of(context).pop(candidate),
                            child: const Text('Choisir'),
                          ),
                          onTap: () => Navigator.of(context).pop(candidate),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _searchCandidates(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _candidates = const [];
        _errorMessage = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final data = await _service.fetchMemberCandidates(
        widget.groupId,
        query: query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = data;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }
}
