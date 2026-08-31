import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/groups/data/services/client_group_invitations_service.dart';
import 'package:mobile/features/groups/data/services/client_groups_service.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';
import 'package:mobile/features/groups/presentation/screens/group_invitation_screen.dart';

enum AdhesionFilter { all, received, sent }

enum AdhesionType {
  invitationReceived, // Analogue : Appel reçu 📥
  requestSent,        // Analogue : Appel émis ↗️
}

class UnifiedAdhesionItem {
  final AdhesionType type;
  final String groupName;
  final String reference;
  final int memberCount;
  final int participantCount;
  final double contributionAmount;
  final int turnIntervalValue;
  final String turnIntervalUnit;
  final DateTime? date;
  final String? agentName;
  final GroupInvitationPreview? invitation;
  final ClientGroupMembership? request;

  UnifiedAdhesionItem.fromInvitation(GroupInvitationPreview inv)
      : type = AdhesionType.invitationReceived,
        groupName = inv.groupName,
        reference = inv.reference,
        memberCount = inv.memberCount,
        participantCount = inv.participantCount,
        contributionAmount = inv.contributionAmount,
        turnIntervalValue = inv.turnIntervalValue,
        turnIntervalUnit = inv.turnIntervalUnit,
        date = inv.plannedStartDate,
        agentName = null,
        invitation = inv,
        request = null;

  UnifiedAdhesionItem.fromRequest(ClientGroupMembership req)
      : type = AdhesionType.requestSent,
        groupName = req.name,
        reference = req.reference,
        memberCount = req.memberCount,
        participantCount = req.participantCount,
        contributionAmount = req.contributionAmount,
        turnIntervalValue = req.turnIntervalValue,
        turnIntervalUnit = req.turnIntervalUnit,
        date = req.joinedAt,
        agentName = req.agent?.displayName,
        invitation = null,
        request = req;
}

class UnifiedAdhesionsSection extends StatefulWidget {
  final ValueChanged<int>? onInvitationCountChanged;
  final ValueChanged<int>? onRequestCountChanged;

  const UnifiedAdhesionsSection({
    super.key,
    this.onInvitationCountChanged,
    this.onRequestCountChanged,
  });

  @override
  State<UnifiedAdhesionsSection> createState() =>
      _UnifiedAdhesionsSectionState();
}

class _UnifiedAdhesionsSectionState extends State<UnifiedAdhesionsSection> {
  final _invitationsService = ClientGroupInvitationsService();
  final _requestsService = ClientGroupsService();

  late Future<void> _dataFuture;
  List<GroupInvitationPreview> _invitations = [];
  List<ClientGroupMembership> _requests = [];
  AdhesionFilter _activeFilter = AdhesionFilter.all;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadAll();
  }

  Future<void> _loadAll() async {
    final results = await Future.wait([
      _invitationsService
          .fetchPendingInvitations()
          .catchError((_) => <GroupInvitationPreview>[]),
      _requestsService
          .fetchMyGroupRequests()
          .catchError((_) => <ClientGroupMembership>[]),
    ]);

    _invitations = results[0] as List<GroupInvitationPreview>;
    _requests = results[1] as List<ClientGroupMembership>;

    widget.onInvitationCountChanged?.call(_invitations.length);
    widget.onRequestCountChanged?.call(_requests.length);
  }

  void _reload() {
    setState(() {
      _dataFuture = _loadAll();
    });
  }

  List<UnifiedAdhesionItem> get _unifiedItems {
    final list = <UnifiedAdhesionItem>[];
    for (final inv in _invitations) {
      list.add(UnifiedAdhesionItem.fromInvitation(inv));
    }
    for (final req in _requests) {
      list.add(UnifiedAdhesionItem.fromRequest(req));
    }
    list.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return list;
  }

  List<UnifiedAdhesionItem> get _filteredItems {
    final all = _unifiedItems;
    switch (_activeFilter) {
      case AdhesionFilter.received:
        return all
            .where((item) => item.type == AdhesionType.invitationReceived)
            .toList();
      case AdhesionFilter.sent:
        return all
            .where((item) => item.type == AdhesionType.requestSent)
            .toList();
      case AdhesionFilter.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final allItems = _unifiedItems;
        final filtered = _filteredItems;
        final receivedCount = _invitations.length;
        final sentCount = _requests.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtres style journal d'appels : Tous, Reçues, Envoyées
            if (allItems.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'Toutes',
                      count: allItems.length,
                      filter: AdhesionFilter.all,
                      icon: Icons.list_alt_rounded,
                      activeColor: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Invitations reçues',
                      count: receivedCount,
                      filter: AdhesionFilter.received,
                      icon: Icons.call_received_rounded,
                      activeColor: const Color(0xFF059669),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Demandes envoyées',
                      count: sentCount,
                      filter: AdhesionFilter.sent,
                      icon: Icons.call_made_rounded,
                      activeColor: const Color(0xFFD97706),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Contenu principal : liste unifiée ou bloc vide
            if (filtered.isEmpty)
              _buildEmptyState(context, allItems.isEmpty)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildAdhesionCard(context, item);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required AdhesionFilter filter,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _activeFilter == filter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _activeFilter = filter;
          });
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : AppTheme.primaryColor.withValues(alpha: 0.12),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : activeColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimaryColor,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : activeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : activeColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdhesionCard(BuildContext context, UnifiedAdhesionItem item) {
    final isReceived = item.type == AdhesionType.invitationReceived;
    final themeColor = isReceived
        ? const Color(0xFF059669) // Vert émeraude pour invitation reçue (Appel reçu)
        : const Color(0xFFD97706); // Ambre / Orange chaud pour demande émise (Appel émis)

    final lightBg = isReceived
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFFBEB);

    final badgeBg = isReceived
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFEF3C7);

    final statusIcon = isReceived
        ? Icons.call_received_rounded
        : Icons.call_made_rounded;

    final typeLabel = isReceived ? 'Invitation reçue' : 'Demande envoyée';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bordure latérale distinctive couleur appel reçu / émis
            Container(
              width: 5,
              color: themeColor,
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne supérieure : Nom du groupe + Badge d'état d'appel
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône d'appel (reçu vert ou émis ambre)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: lightBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            statusIcon,
                            color: themeColor,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.groupName,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 11,
                                          color: themeColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          typeLabel,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: themeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isReceived) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '• En attente',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: Colors.grey.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 10),

                    // Détails du groupe : participants, cotisation, date / agent
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 15,
                          color: AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.memberCount}/${item.participantCount} membres',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        if (item.contributionAmount > 0) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.savings_outlined,
                            size: 15,
                            color: AppTheme.accentDarkColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${formatFCFA(item.contributionAmount)} F',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentDarkColor,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (!isReceived && item.agentName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            size: 15,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Agent : ${item.agentName}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          if (item.date != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• Envoyée le ${_formatDate(item.date)}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],

                    // Action rapide si c'est une invitation reçue
                    if (isReceived && item.invitation != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => GroupInvitationScreen(
                                    token: item.invitation!.token,
                                    launchedFromPending: true,
                                  ),
                                ),
                              );
                              if (mounted) {
                                _reload();
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Répondre',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isCompletelyEmpty) {
    String title;
    String subtitle;
    IconData icon;

    if (isCompletelyEmpty) {
      title = 'Aucune adhésion en cours';
      subtitle =
          'Vos invitations de groupe reçues et vos demandes d\'adhésion envoyées apparaîtront ici.';
      icon = Icons.mark_email_read_outlined;
    } else if (_activeFilter == AdhesionFilter.received) {
      title = 'Aucune invitation reçue';
      subtitle =
          'Vous n\'avez actuellement aucune invitation reçue en attente de réponse.';
      icon = Icons.call_received_rounded;
    } else {
      title = 'Aucune demande envoyée';
      subtitle =
          'Toutes vos demandes d\'adhésion ont été traitées ou vous n\'en avez pas encore émise.';
      icon = Icons.call_made_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    return DateFormat('dd/MM/yyyy').format(value);
  }
}
