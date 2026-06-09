import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/features/groups/data/services/group_invitation_service.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';

class GroupInvitationScreen extends StatefulWidget {
  final String token;
  final bool launchedFromPending;

  const GroupInvitationScreen({
    super.key,
    required this.token,
    this.launchedFromPending = false,
  });

  @override
  State<GroupInvitationScreen> createState() => _GroupInvitationScreenState();
}

class _GroupInvitationScreenState extends State<GroupInvitationScreen> {
  final _service = GroupInvitationService();
  late Future<GroupInvitationPreview> _previewFuture;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _previewFuture = _service.fetchPreview(widget.token);
  }

  void _reload() {
    setState(() {
      _previewFuture = _service.fetchPreview(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation groupe')),
      body: FutureBuilder<GroupInvitationPreview>(
        future: _previewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            return _InvitationStateView(
              icon: Icons.link_off_rounded,
              title: 'Invitation indisponible',
              message: error is ApiException
                  ? error.message
                  : 'Impossible de charger cette invitation.',
              actionLabel: 'Reessayer',
              onPressed: _reload,
            );
          }

          final invitation = snapshot.data!;
          return FutureBuilder<bool>(
            future: SessionStorage.hasActiveSession(),
            builder: (context, authSnapshot) {
              final isLoggedIn = authSnapshot.data ?? false;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _InvitationHeroCard(invitation: invitation),
                  const SizedBox(height: 18),
                  _InvitationFactsCard(invitation: invitation),
                  const SizedBox(height: 18),
                  if ((invitation.description ?? '').trim().isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(invitation.description!),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!isLoggedIn)
                    FilledButton.icon(
                      onPressed: _goToLogin,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(
                        invitation.invitationType == 'open'
                            ? 'Se connecter pour envoyer la demande'
                            : 'Se connecter pour rejoindre',
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _isAccepting || _isDeclining
                          ? null
                          : _acceptInvitation,
                      icon: _isAccepting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.group_add_rounded),
                      label: Text(
                        _isAccepting
                            ? 'Adhesion en cours...'
                            : invitation.invitationType == 'open'
                            ? 'Envoyer ma demande'
                            : 'Rejoindre ce groupe',
                      ),
                    ),
                  if (isLoggedIn && invitation.invitationType == 'targeted') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isAccepting || _isDeclining
                          ? null
                          : _declineInvitation,
                      icon: _isDeclining
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close_rounded),
                      label: Text(
                        _isDeclining
                            ? 'Refus en cours...'
                            : 'Refuser cette invitation',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      widget.launchedFromPending ? 'Plus tard' : 'Fermer',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _goToLogin() async {
    await SessionStorage.savePendingGroupInvitationToken(widget.token);
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/auth_choice', (route) => false);
  }

  Future<void> _acceptInvitation() async {
    setState(() {
      _isAccepting = true;
    });

    try {
      final invitation = await _service.accept(widget.token);
      await SessionStorage.clearPendingGroupInvitationToken();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              invitation.membershipStatus == 'requested'
                  ? 'Votre demande a ete envoyee a l agent pour le groupe ${invitation.groupName}.'
                  : 'Vous avez rejoint le groupe ${invitation.groupName}.',
            ),
          ),
        );
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isAccepting = false;
        });
      }
    }
  }

  Future<void> _declineInvitation() async {
    setState(() {
      _isDeclining = true;
    });

    try {
      await _service.decline(widget.token);
      await SessionStorage.clearPendingGroupInvitationToken();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Invitation refusee avec succes.'),
          ),
        );
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isDeclining = false;
        });
      }
    }
  }
}

class _InvitationHeroCard extends StatelessWidget {
  final GroupInvitationPreview invitation;

  const _InvitationHeroCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitation.groupName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(invitation.reference),
            const SizedBox(height: 12),
            Text(
              '${invitation.memberCount}/${invitation.participantCount} participants',
            ),
            const SizedBox(height: 6),
            Text(
              'Places restantes: ${invitation.remainingSlots}',
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationFactsCard extends StatelessWidget {
  final GroupInvitationPreview invitation;

  const _InvitationFactsCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FactRow(
              label: 'Montant par tour',
              value: '${invitation.contributionAmount.toStringAsFixed(0)} F',
            ),
            const SizedBox(height: 10),
            _FactRow(
              label: 'Frequence',
              value:
                  '${invitation.turnIntervalValue} ${_unitLabel(invitation.turnIntervalUnit)}',
            ),
            const SizedBox(height: 10),
            _FactRow(
              label: 'Debut prevu',
              value: _formatDate(invitation.plannedStartDate),
            ),
            const SizedBox(height: 10),
            _FactRow(
              label: 'Statut',
              value: _launchLabel(invitation.launchStatus),
            ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(String value) {
    switch (value) {
      case 'day':
        return 'jour(s)';
      case 'week':
        return 'semaine(s)';
      case 'month':
      default:
        return 'mois';
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Non definie';
    }
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InvitationStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _InvitationStateView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
