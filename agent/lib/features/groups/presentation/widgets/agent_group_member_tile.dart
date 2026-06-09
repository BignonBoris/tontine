import 'package:agent/features/groups/domain/entities/agent_group_member.dart';
import 'package:flutter/material.dart';

class AgentGroupMemberTile extends StatelessWidget {
  final AgentGroupMember member;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AgentGroupMemberTile({
    super.key,
    required this.member,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final client = member.client;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(
                alpha: 0.10,
              ),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.person_outline_rounded),
        ),
        title: Text(client?.displayName ?? 'Client introuvable'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _StatusBadge(member: member),
            if (member.turnPosition != null || member.minimumEligibleTurn != null) ...[
              const SizedBox(height: 6),
              Text(
                [
                  if (member.turnPosition != null)
                    'Tour ${member.turnPosition}',
                  if (member.minimumEligibleTurn != null)
                    'Min ${member.minimumEligibleTurn}',
                ].join(' | '),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              client == null
                  ? 'Participant sans fiche client'
                  : '${client.phoneNumber}${client.address?.isNotEmpty == true ? ' â€¢ ${client.address}' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: trailing,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AgentGroupMember member;

  const _StatusBadge({required this.member});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color foreground;
    late final Color background;

    if (member.isInvited) {
      label = 'Invitation en attente';
      foreground = const Color(0xFF175CD3);
      background = const Color(0xFFEAF2FF);
    } else if (member.isRequested) {
      label = 'Demande a valider';
      foreground = const Color(0xFF7A2E0E);
      background = const Color(0xFFFFEAD5);
    } else if (member.isDeclined) {
      label = 'Invitation refusee';
      foreground = const Color(0xFFB42318);
      background = const Color(0xFFFEE4E2);
    } else if (member.isRejected) {
      label = 'Demande refusee';
      foreground = const Color(0xFFB42318);
      background = const Color(0xFFFEE4E2);
    } else if (member.isRemoved) {
      label = 'Retire';
      foreground = const Color(0xFFB54708);
      background = const Color(0xFFFFF1E8);
    } else {
      label = 'Actif';
      foreground = const Color(0xFF067647);
      background = const Color(0xFFE7F6EC);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
