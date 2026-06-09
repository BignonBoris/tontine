import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/data/services/client_groups_service.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';
import 'package:mobile/features/groups/presentation/screens/client_group_detail_screen.dart';

class MyGroupsSection extends StatefulWidget {
  const MyGroupsSection({super.key});

  @override
  State<MyGroupsSection> createState() => _MyGroupsSectionState();
}

class _MyGroupsSectionState extends State<MyGroupsSection> {
  final _service = ClientGroupsService();
  late Future<List<ClientGroupMembership>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMyGroups();
  }

  void _reload() {
    setState(() {
      _future = _service.fetchMyGroups();
    });
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
              : 'Impossible de charger vos groupes.';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.groups_2_outlined, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Groupes indisponibles',
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

        final groups = snapshot.data ?? const <ClientGroupMembership>[];
        if (groups.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.groups_2_outlined, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'Aucun groupe rejoint',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Scannez un QR code ou ouvrez un lien d invitation pour rejoindre une tontine de groupe.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: groups
              .map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${group.memberCount}'),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        '${group.memberCount}/${group.participantCount} participants | ${_launchLabel(group.launchStatus)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ClientGroupDetailScreen(groupId: group.id),
                          ),
                        );
                      },
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

String _launchLabel(String value) {
  switch (value) {
    case 'ready':
      return 'Pret';
    case 'started':
      return 'Demarre';
    case 'launch_cancelled':
      return 'Annule';
    case 'collecting':
    default:
      return 'En constitution';
  }
}
