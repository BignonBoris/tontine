import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/data/services/client_group_invitations_service.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';
import 'package:mobile/features/groups/presentation/screens/group_invitation_screen.dart';

class PendingGroupInvitationsSection extends StatefulWidget {
  final ValueChanged<int>? onCountChanged;

  const PendingGroupInvitationsSection({
    super.key,
    this.onCountChanged,
  });

  @override
  State<PendingGroupInvitationsSection> createState() =>
      _PendingGroupInvitationsSectionState();
}

class _PendingGroupInvitationsSectionState
    extends State<PendingGroupInvitationsSection> {
  final _service = ClientGroupInvitationsService();
  late Future<List<GroupInvitationPreview>> _future;

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

  Future<List<GroupInvitationPreview>> _load() async {
    final invitations = await _service.fetchPendingInvitations();
    widget.onCountChanged?.call(invitations.length);
    return invitations;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupInvitationPreview>>(
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
              : 'Impossible de charger vos invitations.';
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.mail_outline_rounded, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Invitations indisponibles',
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

        final invitations = snapshot.data ?? const <GroupInvitationPreview>[];
        if (invitations.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.mark_email_read_outlined, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'Aucune invitation en attente',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Les nouvelles invitations de groupe apparaitront ici.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: invitations
              .map(
                (invitation) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.mail_outline_rounded),
                      ),
                      title: Text(invitation.groupName),
                      subtitle: Text(
                        '${invitation.memberCount}/${invitation.participantCount} participants | ${_launchLabel(invitation.launchStatus)}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GroupInvitationScreen(
                              token: invitation.token,
                            ),
                          ),
                        );
                        if (mounted) {
                          _reload();
                        }
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
