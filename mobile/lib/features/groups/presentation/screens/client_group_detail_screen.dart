import 'package:flutter/material.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/groups/data/services/client_groups_service.dart';
import 'package:mobile/features/groups/domain/entities/client_group_contribution.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';

class ClientGroupDetailScreen extends StatefulWidget {
  final String groupId;

  const ClientGroupDetailScreen({super.key, required this.groupId});

  @override
  State<ClientGroupDetailScreen> createState() => _ClientGroupDetailScreenState();
}

class _ClientGroupDetailScreenState extends State<ClientGroupDetailScreen> {
  final _service = ClientGroupsService();
  late Future<ClientGroupMembership> _future;
  late Future<List<ClientGroupContribution>> _contributionsFuture;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchGroupDetail(widget.groupId);
    _contributionsFuture = _service.fetchGroupContributions(widget.groupId);
  }

  void _reload() {
    setState(() {
      _future = _service.fetchGroupDetail(widget.groupId);
      _contributionsFuture = _service.fetchGroupContributions(widget.groupId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon groupe')),
      body: FutureBuilder<ClientGroupMembership>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is ApiException
                ? error.message
                : 'Impossible de charger ce groupe.';
            return _ClientGroupStateView(
              icon: Icons.groups_2_outlined,
              title: 'Detail indisponible',
              message: message,
              actionLabel: 'Reessayer',
              onPressed: _reload,
            );
          }

          final group = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ClientGroupHeroCard(group: group),
              const SizedBox(height: 18),
              _ClientGroupFactsCard(group: group),
              if ((group.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(group.description!),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FutureBuilder<List<ClientGroupContribution>>(
                future: _contributionsFuture,
                builder: (context, contributionSnapshot) {
                  if (contributionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (contributionSnapshot.hasError) {
                    final error = contributionSnapshot.error;
                    final message = error is ApiException
                        ? error.message
                        : 'Impossible de charger vos cotisations.';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(message),
                      ),
                    );
                  }

                  final contributions =
                      contributionSnapshot.data ?? const <ClientGroupContribution>[];
                  if (contributions.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final nextContribution = contributions.firstWhere(
                    (item) => !item.isPaid,
                    orElse: () => contributions.first,
                  );

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ma prochaine cotisation',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          _FactRow(
                            label: 'Tour',
                            value: '${nextContribution.turnNumber}',
                          ),
                          const SizedBox(height: 10),
                          _FactRow(
                            label: 'Montant',
                            value: '${nextContribution.amount.toStringAsFixed(0)} F',
                          ),
                          const SizedBox(height: 10),
                          _FactRow(
                            label: 'Beneficiaire',
                            value: nextContribution.beneficiary?.displayName ??
                                'Non defini',
                          ),
                          const SizedBox(height: 10),
                          _FactRow(
                            label: 'Statut',
                            value: nextContribution.isPaid ? 'Payee' : 'En attente',
                          ),
                          if (!nextContribution.isPaid) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _payContribution(nextContribution.id),
                                child: const Text(
                                  'Payer depuis le solde disponible',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _payContribution(String contributionId) async {
    try {
      await _service.payContribution(contributionId);
      if (!mounted) {
        return;
      }
      _reload();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Cotisation de groupe payee avec succes.'),
          ),
        );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ClientGroupHeroCard extends StatelessWidget {
  final ClientGroupMembership group;

  const _ClientGroupHeroCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(group.reference),
            const SizedBox(height: 12),
            Text('${group.memberCount}/${group.participantCount} participants'),
            const SizedBox(height: 6),
            Text('Mon adhesion: ${_formatDate(group.joinedAt)}'),
          ],
        ),
      ),
    );
  }
}

class _ClientGroupFactsCard extends StatelessWidget {
  final ClientGroupMembership group;

  const _ClientGroupFactsCard({required this.group});

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
              value: '${group.contributionAmount.toStringAsFixed(0)} F',
            ),
            const SizedBox(height: 10),
            _FactRow(
              label: 'Frequence',
              value: '${group.turnIntervalValue} ${_unitLabel(group.turnIntervalUnit)}',
            ),
            const SizedBox(height: 10),
            _FactRow(
              label: 'Debut prevu',
              value: _formatDate(group.plannedStartDate),
            ),
            const SizedBox(height: 10),
            _FactRow(
              label: 'Statut',
              value: _launchLabel(group.launchStatus),
            ),
            if (group.agent != null) ...[
              const SizedBox(height: 10),
              _FactRow(
                label: 'Agent responsable',
                value: group.agent!.displayName,
              ),
            ],
          ],
        ),
      ),
    );
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

class _ClientGroupStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _ClientGroupStateView({
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
