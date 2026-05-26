import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/data/services/client_groups_service.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';

class PendingGroupRequestsSection extends StatefulWidget {
  final ValueChanged<int>? onCountChanged;

  const PendingGroupRequestsSection({
    super.key,
    this.onCountChanged,
  });

  @override
  State<PendingGroupRequestsSection> createState() =>
      _PendingGroupRequestsSectionState();
}

class _PendingGroupRequestsSectionState
    extends State<PendingGroupRequestsSection> {
  final _service = ClientGroupsService();
  late Future<List<ClientGroupMembership>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<List<ClientGroupMembership>> _load() async {
    final requests = await _service.fetchMyGroupRequests();
    widget.onCountChanged?.call(requests.length);
    return requests;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ClientGroupMembership>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Impossible de charger vos demandes.';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.hourglass_top_rounded, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Demandes indisponibles',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Reessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final requests = snapshot.data ?? const <ClientGroupMembership>[];
        if (requests.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.mark_email_unread_outlined, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'Aucune demande en attente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Les demandes envoyees par lien ou QR apparaitront ici jusqu a validation par un agent.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: requests
              .map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.hourglass_top_rounded),
                      ),
                      title: Text(group.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEAD5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'En attente de validation',
                              style: TextStyle(
                                color: Color(0xFF7A2E0E),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${group.memberCount}/${group.participantCount} participants | ${group.agent?.displayName ?? 'Agent'}\nDemande envoyee: ${_formatDate(group.joinedAt)}',
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.schedule_rounded),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'Date indisponible';
  }
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  return '$day/$month/$year';
}
