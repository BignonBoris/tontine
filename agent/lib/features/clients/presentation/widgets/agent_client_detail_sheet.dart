import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/utils/currency_formatter.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/clients/data/services/agent_client_service.dart';
import 'package:agent/features/clients/domain/entities/agent_client.dart';
import 'package:agent/features/clients/presentation/widgets/agent_start_tontine_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AgentClientDetailSheet extends StatefulWidget {
  final String clientId;

  const AgentClientDetailSheet({
    super.key,
    required this.clientId,
  });

  @override
  State<AgentClientDetailSheet> createState() => _AgentClientDetailSheetState();
}

class _AgentClientDetailSheetState extends State<AgentClientDetailSheet> {
  final _service = AgentClientService();
  late Future<AgentClient> _clientFuture;

  @override
  void initState() {
    super.initState();
    _clientFuture = _service.fetchMyClientDetail(widget.clientId);
  }

  void _reload() {
    setState(() {
      _clientFuture = _service.fetchMyClientDetail(widget.clientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: FutureBuilder<AgentClient>(
          future: _clientFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 420,
                child: AgentLoadingView(
                  message: 'Chargement de la fiche client...',
                ),
              );
            }

            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is ApiException
                  ? error.message
                  : 'Impossible de charger la fiche client.';
              return SizedBox(
                height: 420,
                child: AgentErrorView(
                  title: 'Fiche indisponible',
                  message: message,
                  onRetry: _reload,
                ),
              );
            }

            final client = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: SizedBox(width: 44, child: Divider(thickness: 4)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    client.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(client.phoneNumber),
                  if ((client.address ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(client.address!),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        label: client.hasActiveTontine
                            ? 'Tontine active'
                            : 'Aucune tontine active',
                      ),
                      _InfoChip(
                        label:
                            'Cree le ${_formatDate(client.memberSince, fallback: '-')}',
                      ),
                      _InfoChip(
                        label:
                            'Derniere operation ${_formatDate(client.lastOperationAt, fallback: 'Aucune')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SoftSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle(
                          title: 'Situation actuelle',
                          subtitle: 'Lecture rapide de la situation du client.',
                        ),
                        const SizedBox(height: 14),
                        _MetricRow(
                          label: 'Mise actuelle',
                          value: client.hasActiveTontine
                              ? formatFcfa(client.currentStakeAmount)
                              : 'Aucune',
                        ),
                        const SizedBox(height: 10),
                        _MetricRow(
                          label: 'Solde tontine',
                          value: formatFcfa(client.tontineBalance),
                        ),
                        const SizedBox(height: 10),
                        _MetricRow(
                          label: 'Solde disponible',
                          value: formatFcfa(client.availableBalance),
                        ),
                      ],
                    ),
                  ),
                  if (client.latestProvisionings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SoftSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(
                            title: 'Derniers depots',
                            subtitle: 'Historique recent du client.',
                          ),
                          const SizedBox(height: 14),
                          ...client.latestProvisionings.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MetricRow(
                                label: item.reference,
                                value: formatFcfa(item.amount),
                                helper: _formatDate(
                                  item.validatedAt ?? item.createdAt,
                                  fallback: '',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!client.hasActiveTontine) ...[
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () => _openStartTontine(client),
                      child: const Text('Demarrer une tontine'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openStartTontine(AgentClient client) async {
    final result = await showModalBottomSheet<AgentClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentStartTontineSheet(client: client),
    );

    if (!mounted || result == null) {
      return;
    }
    _reload();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Tontine demarree avec succes.')),
      );
  }

  String _formatDate(DateTime? date, {required String fallback}) {
    if (date == null) {
      return fallback;
    }
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  const _MetricRow({
    required this.label,
    required this.value,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                ),
              ),
              if (helper != null && helper!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  helper!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF475467),
        ),
      ),
    );
  }
}
