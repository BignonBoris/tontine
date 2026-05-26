import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/groups/data/services/agent_group_service.dart';
import 'package:agent/features/groups/domain/entities/agent_group.dart';
import 'package:agent/features/groups/domain/entities/agent_group_contribution.dart';
import 'package:agent/features/groups/domain/entities/agent_group_invitation.dart';
import 'package:agent/features/groups/domain/entities/agent_group_member.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_candidate_search_sheet.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_form_sheet.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_member_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _service = AgentGroupService();
  late Future<_GroupDetailViewModel> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _load();
  }

  Future<_GroupDetailViewModel> _load() async {
    final results = await Future.wait([
      _service.fetchGroupDetail(widget.groupId),
      _service.fetchMembers(widget.groupId),
      _service.fetchContributions(widget.groupId),
    ]);
    return _GroupDetailViewModel(
      group: results[0] as AgentGroup,
      members: results[1] as List<AgentGroupMember>,
      turns: results[2] as List<AgentGroupTurn>,
    );
  }

  void _reload() {
    setState(() {
      _detailFuture = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GroupDetailViewModel>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final group = snapshot.data?.group;
          final canShareInvitation =
              group != null &&
              !group.isStarted &&
              group.status == 'active' &&
              group.launchStatus != 'launch_cancelled' &&
              group.memberCount < group.participantCount;

          return Scaffold(
            appBar: AppBar(
              title: Text(group?.name ?? 'Detail groupe'),
              actions: group == null
                  ? null
                  : _buildHeaderActions(
                      group,
                      canShareInvitation: canShareInvitation,
                    ),
            ),
            body:
            snapshot.connectionState == ConnectionState.waiting
                ? const AgentLoadingView(
                    message: 'Chargement du groupe et de ses participants...',
                  )
                : snapshot.hasError
                ? AgentErrorView(
                    title: 'Detail indisponible',
                    message: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'Impossible de charger le detail du groupe.',
                    onRetry: _reload,
                  )
                : _buildLoadedView(
                    context,
                    snapshot.data!,
                    canShareInvitation: canShareInvitation,
                  ),
          );
        },
      );
  }

  Widget _buildLoadedView(
    BuildContext context,
    _GroupDetailViewModel data, {
    required bool canShareInvitation,
  }) {
    final group = data.group;
    final members = data.members;
    final turns = data.turns;
    final currentTurn = turns.cast<AgentGroupTurn?>().firstWhere(
          (turn) => turn != null && turn.paidCount < turn.totalCount,
          orElse: () => turns.isNotEmpty ? turns.first : null,
        );

    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _GroupMetricItem(
                      icon: Icons.group_outlined,
                      label: '${group.memberCount}/${group.participantCount}',
                    ),
                    _GroupMetricItem(
                      icon: Icons.event_repeat_rounded,
                      label:
                          '${group.turnIntervalValue} ${_unitLabel(group.turnIntervalUnit)}',
                    ),
                    _GroupMetricItem(
                      icon: Icons.payments_outlined,
                      label: '${group.contributionAmount.toStringAsFixed(0)} F',
                    ),
                    _GroupMetricItem(
                      icon: Icons.event_rounded,
                      label: _formatDate(group.plannedStartDate),
                      color: _scheduleColor(group),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GroupTag(
                      label: group.isActive ? 'Actif' : 'Suspendu',
                      foregroundColor: group.isActive
                          ? const Color(0xFF067647)
                          : const Color(0xFFB54708),
                      backgroundColor: group.isActive
                          ? const Color(0xFFE7F6EC)
                          : const Color(0xFFFFF1E8),
                    ),
                    _GroupTag(
                      label: _launchLabel(group.launchStatus),
                      foregroundColor:
                          _launchTagColors(group.launchStatus).foreground,
                      backgroundColor:
                          _launchTagColors(group.launchStatus).background,
                    ),
                  ],
                ),
                if ((group.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(group.description!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionTitle(
            title: 'Participants',
            subtitle: group.isStarted
                ? 'La liste est figee apres demarrage.'
                : 'Ajoutez ou retirez les participants avant demarrage.',
            trailing: null,
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            const SizedBox(
              height: 220,
              child: AgentEmptyView(
                icon: Icons.groups_2_outlined,
                title: 'Aucun participant actif',
                message:
                    'Ajoutez des clients existants pour constituer ce groupe.',
              ),
            )
          else
            ...members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AgentGroupMemberTile(
                  member: member,
                  trailing: _buildMemberTrailing(group, member),
                ),
              ),
            ),
          if (group.isStarted && currentTurn != null) ...[
            const SizedBox(height: 18),
            SectionTitle(
              title: 'Tour en cours',
              subtitle:
                  'Encaissez les cotisations du tour ${currentTurn.turnNumber}.',
              trailing: null,
            ),
            const SizedBox(height: 12),
            SoftSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Beneficiaire: ${currentTurn.beneficiary?.displayName ?? 'Non defini'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cotisations: ${currentTurn.paidCount}/${currentTurn.totalCount} | Montant: ${currentTurn.amount.toStringAsFixed(0)} F',
                  ),
                  const SizedBox(height: 12),
                  ...currentTurn.contributions.map(
                    (contribution) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        contribution.member?.displayName ?? 'Participant',
                      ),
                      subtitle: Text(
                        contribution.isPaid
                            ? 'Reglee'
                            : 'En attente',
                      ),
                      trailing: contribution.isPaid
                          ? const Icon(Icons.check_circle, color: Color(0xFF067647))
                          : TextButton(
                              onPressed: () => _collectContribution(
                                group,
                                contribution,
                              ),
                              child: const Text('Encaisser'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildMemberTrailing(AgentGroup group, AgentGroupMember member) {
    if (group.isStarted) {
      return null;
    }

    if (member.isRequested) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _approveRequestedMember(group, member),
            icon: const Icon(Icons.check_circle_outline_rounded),
            tooltip: 'Valider la demande',
          ),
          IconButton(
            onPressed: () => _rejectRequestedMember(group, member),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Refuser la demande',
          ),
        ],
      );
    }

    if ((member.isRemoved || member.isDeclined || member.isRejected) &&
        member.client != null) {
      return IconButton(
        onPressed: () => _inviteExistingMember(group, member),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        tooltip: 'Reinviter dans le groupe',
      );
    }

    if (member.isActive || member.isInvited) {
      return IconButton(
        onPressed: () => _removeMember(group, member),
        icon: const Icon(Icons.person_remove_outlined),
        tooltip: 'Retirer du groupe',
      );
    }

    return null;
  }

  List<Widget> _buildHeaderActions(
    AgentGroup group, {
    required bool canShareInvitation,
  }) {
    return [
      if (!group.isStarted)
        IconButton(
          onPressed: () => _openCandidateSearch(group),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          tooltip: 'Ajouter un participant',
        ),
      PopupMenuButton<String>(
        tooltip: 'Actions du groupe',
        onSelected: (value) => _handleHeaderAction(
          value,
          group,
          canShareInvitation: canShareInvitation,
        ),
        itemBuilder: (context) => _buildHeaderMenuItems(
          group,
          canShareInvitation: canShareInvitation,
        ),
      ),
    ];
  }

  List<PopupMenuEntry<String>> _buildHeaderMenuItems(
    AgentGroup group, {
    required bool canShareInvitation,
  }) {
    final items = <PopupMenuEntry<String>>[];

    if (!group.isStarted) {
      items.add(_MenuSectionHeader(title: 'Groupe'));

        if (group.status == 'active' && group.launchStatus != 'launch_cancelled') {
          items.add(
          const PopupMenuItem<String>(
            value: 'launch',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.play_circle_outline_rounded),
              title: Text('Lancer la tontine'),
            ),
          ),
        );
      }

      items.addAll(const [
        PopupMenuItem<String>(
          value: 'turn_order',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.format_list_numbered_rounded),
            title: Text('Organiser les tours'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'postpone',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.event_repeat_rounded),
            title: Text('Prolonger la date'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'reduce_target',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.group_remove_outlined),
            title: Text('Reduire a l effectif actuel'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'cancel_launch',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.cancel_schedule_send_outlined),
            title: Text('Annuler le lancement'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier le groupe'),
          ),
        ),
      ]);
      items.add(const PopupMenuDivider());
    }

    items.add(_MenuSectionHeader(title: 'Statut'));
    items.add(
      PopupMenuItem<String>(
        value: group.isActive ? 'suspend' : 'activate',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            group.isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.check_circle_outline_rounded,
          ),
          title: Text(group.isActive ? 'Suspendre' : 'Reactiver'),
        ),
      ),
    );

    if (canShareInvitation) {
      items.add(const PopupMenuDivider());
      items.add(_MenuSectionHeader(title: 'Invitation'));
      items.addAll(const [
        PopupMenuItem<String>(
          value: 'show_qr',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.qr_code_2_rounded),
            title: Text('Afficher le QR invitation'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_link',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.content_copy_rounded),
            title: Text('Copier le lien invitation'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'share_link',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.share_outlined),
            title: Text('Partager le lien invitation'),
          ),
        ),
      ]);
    }

    return items;
  }

  Future<void> _handleHeaderAction(
    String action,
    AgentGroup group, {
    required bool canShareInvitation,
  }) async {
    switch (action) {
      case 'launch':
        await _launchGroup(group);
        return;
      case 'postpone':
        await _postponeGroup(group);
        return;
      case 'turn_order':
        await _openTurnOrderEditor(group);
        return;
      case 'reduce_target':
        await _reduceTarget(group);
        return;
      case 'cancel_launch':
        await _cancelLaunch(group);
        return;
      case 'edit':
        await _openEditSheet(group);
        return;
      case 'suspend':
        await _changeStatus(group, activate: false);
        return;
      case 'activate':
        await _changeStatus(group, activate: true);
        return;
      case 'show_qr':
        if (canShareInvitation) {
          await _showInvitationQr(group);
        }
        return;
      case 'copy_link':
        if (canShareInvitation) {
          await _copyInvitationLink(group);
        }
        return;
      case 'share_link':
        if (canShareInvitation) {
          await _shareInvitationLink(group);
        }
        return;
    }
  }

  Future<void> _openCandidateSearch(AgentGroup group) async {
    final candidate = await showModalBottomSheet<AgentGroupCandidate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: AgentGroupCandidateSearchSheet(groupId: group.id),
      ),
    );

    if (!mounted || candidate == null) {
      return;
    }

    final shouldInvite = await _confirmMemberInvitation(
      groupName: group.name,
      candidateName: candidate.displayName,
    );

    if (!mounted || shouldInvite != true) {
      return;
    }

    try {
      await _service.addMember(
        groupId: group.id,
        clientUserId: candidate.id,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Invitation envoyee en attente de confirmation client.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<bool?> _confirmMemberInvitation({
    required String groupName,
    required String candidateName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer l invitation'),
        content: Text(
          'Envoyer une invitation a $candidateName pour rejoindre le groupe $groupName ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditSheet(AgentGroup group) async {
    final result = await showModalBottomSheet<AgentGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AgentGroupFormSheet(initialGroup: group),
    );

    if (!mounted || result == null) {
      return;
    }

    _reload();
    _showMessage('Groupe mis a jour avec succes.');
  }

  Future<void> _openTurnOrderEditor(AgentGroup group) async {
    try {
      final members = await _service.fetchMembers(group.id);
      if (!mounted) {
        return;
      }

      final activeMembers = members.where((member) => member.isActive).toList()
        ..sort((left, right) {
          final leftTurn = left.turnPosition ?? 999;
          final rightTurn = right.turnPosition ?? 999;
          if (leftTurn != rightTurn) {
            return leftTurn.compareTo(rightTurn);
          }
          final leftTime = left.joinedAt?.millisecondsSinceEpoch ?? 0;
          final rightTime = right.joinedAt?.millisecondsSinceEpoch ?? 0;
          return leftTime.compareTo(rightTime);
        });

      if (activeMembers.isEmpty) {
        _showMessage('Aucun membre actif a organiser pour ce groupe.');
        return;
      }

      final orderedIds = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.88,
          child: _TurnOrderSheet(members: activeMembers),
        ),
      );

      if (!mounted || orderedIds == null) {
        return;
      }

      await _service.saveTurnOrder(
        groupId: group.id,
        orderedMemberIds: orderedIds,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Ordre des tours mis a jour avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _removeMember(AgentGroup group, AgentGroupMember member) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer ce participant'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motif de retrait',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || reason == null) {
      return;
    }

    try {
      await _service.removeMember(
        groupId: group.id,
        memberId: member.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Participant retire du groupe.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _inviteExistingMember(
    AgentGroup group,
    AgentGroupMember member,
  ) async {
    final client = member.client;
    if (client == null) {
      _showMessage('Impossible de reinviter ce participant sans fiche client.');
      return;
    }

    final shouldInvite = await _confirmMemberInvitation(
      groupName: group.name,
      candidateName: client.displayName,
    );

    if (!mounted || shouldInvite != true) {
      return;
    }

    try {
      await _service.addMember(
        groupId: group.id,
        clientUserId: client.id,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Invitation renvoyee en attente de confirmation client.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _approveRequestedMember(
    AgentGroup group,
    AgentGroupMember member,
  ) async {
    try {
      await _service.approveMemberRequest(
        groupId: group.id,
        memberId: member.id,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Demande d adhesion validee. Le participant est maintenant actif.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _rejectRequestedMember(
    AgentGroup group,
    AgentGroupMember member,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Refuser cette demande'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motif du refus',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || reason == null) {
      return;
    }

    try {
      await _service.rejectMemberRequest(
        groupId: group.id,
        memberId: member.id,
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Demande d adhesion refusee.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _shareInvitationLink(AgentGroup group) async {
    try {
      final invitation = await _service.fetchInvitationLink(group.id);
      if (!mounted) {
        return;
      }
      final shareText =
          'Demandez a rejoindre le groupe ${group.name} via ce lien: ${invitation.shareUrl}';
      await Share.share(
        shareText,
        subject: 'Invitation au groupe ${group.name}',
      );
      await Clipboard.setData(ClipboardData(text: invitation.shareUrl));
      if (!mounted) {
        return;
      }
      await _showInvitationDialog(invitation);
      _showMessage('Lien d invitation partage et copie dans le presse-papiers.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _collectContribution(
    AgentGroup group,
    AgentGroupContribution contribution,
  ) async {
    try {
      await _service.payContribution(
        groupId: group.id,
        contributionId: contribution.id,
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Cotisation de groupe enregistree avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _copyInvitationLink(AgentGroup group) async {
    try {
      final invitation = await _service.fetchInvitationLink(group.id);
      await Clipboard.setData(ClipboardData(text: invitation.shareUrl));
      if (!mounted) {
        return;
      }
      _showMessage('Lien d invitation copie dans le presse-papiers.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _showInvitationQr(AgentGroup group) async {
    try {
      final invitation = await _service.fetchInvitationLink(group.id);
      if (!mounted) {
        return;
      }
      await Clipboard.setData(ClipboardData(text: invitation.shareUrl));
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'QR d invitation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: invitation.shareUrl,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scannez ce QR pour envoyer une demande d adhesion au groupe ${group.name}.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      _showMessage('QR prepare et lien copie dans le presse-papiers.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _showInvitationDialog(AgentGroupInvitation invitation) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lien d invitation'),
        content: SizedBox(
          width: 320,
          child: SelectableText(invitation.shareUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeStatus(AgentGroup group, {required bool activate}) async {
    try {
      if (activate) {
        await _service.activateGroup(group.id);
      } else {
        await _service.suspendGroup(group.id);
      }
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage(
        activate
            ? 'Groupe reactive avec succes.'
            : 'Groupe suspendu avec succes.',
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _launchGroup(AgentGroup group) async {
    try {
      await _service.launchGroup(group.id);
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Tontine de groupe demarree avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _postponeGroup(AgentGroup group) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate:
          group.plannedStartDate ?? DateTime.now().add(const Duration(days: 7)),
      locale: const Locale('fr', 'FR'),
    );

    if (!mounted || picked == null) {
      return;
    }

    try {
      await _service.postponeGroupLaunch(
        groupId: group.id,
        plannedStartDate: picked.toIso8601String(),
      );
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Date de debut prolongee avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _reduceTarget(AgentGroup group) async {
    try {
      await _service.reduceTargetToCurrentMembers(group.id);
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Nombre cible reduit aux participants actuels.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    }
  }

  Future<void> _cancelLaunch(AgentGroup group) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler le lancement'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Motif'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Annuler le lancement'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || reason == null || reason.isEmpty) {
      return;
    }

    try {
      await _service.cancelGroupLaunch(groupId: group.id, reason: reason);
      if (!mounted) {
        return;
      }
      _reload();
      _showMessage('Lancement du groupe annule avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
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

  Color _scheduleColor(AgentGroup group) {
    final plannedDate = group.plannedStartDate;
    if (plannedDate == null) {
      return const Color(0xFF667085);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      plannedDate.year,
      plannedDate.month,
      plannedDate.day,
    );

    if (startDate.isBefore(today)) {
      return const Color(0xFFB42318);
    }

    return const Color(0xFF067647);
  }

  _TagPalette _launchTagColors(String value) {
    switch (value) {
      case 'ready':
        return const _TagPalette(
          foreground: Color(0xFF175CD3),
          background: Color(0xFFEAF2FF),
        );
      case 'started':
        return const _TagPalette(
          foreground: Color(0xFF7A2E0E),
          background: Color(0xFFFFEAD5),
        );
      case 'launch_cancelled':
        return const _TagPalette(
          foreground: Color(0xFFB42318),
          background: Color(0xFFFEE4E2),
        );
      case 'collecting':
      default:
        return const _TagPalette(
          foreground: Color(0xFF344054),
          background: Color(0xFFF2F4F7),
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
}

class _GroupDetailViewModel {
  final AgentGroup group;
  final List<AgentGroupMember> members;
  final List<AgentGroupTurn> turns;

  const _GroupDetailViewModel({
    required this.group,
    required this.members,
    required this.turns,
  });
}

class _TurnOrderSheet extends StatefulWidget {
  final List<AgentGroupMember> members;

  const _TurnOrderSheet({required this.members});

  @override
  State<_TurnOrderSheet> createState() => _TurnOrderSheetState();
}

class _TurnOrderSheetState extends State<_TurnOrderSheet> {
  late List<AgentGroupMember> _members;

  @override
  void initState() {
    super.initState();
    _members = List<AgentGroupMember>.from(widget.members);
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Organiser les tours',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'L ordre initial suit l adhesion. Vous pouvez reordonner sans placer un membre avant son rang minimum.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final minimumTurn = member.minimumEligibleTurn ?? 1;
                  final canMoveUp =
                      index > 0 && index >= minimumTurn - 1;
                  final canMoveDown = index < _members.length - 1;

                  return Card(
                    child: ListTile(
                      title: Text(member.client?.displayName ?? 'Client'),
                      subtitle: Text(
                        'Tour ${index + 1} | Minimum ${member.minimumEligibleTurn ?? '-'}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: canMoveUp ? () => _move(index, -1) : null,
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            onPressed:
                                canMoveDown ? () => _move(index, 1) : null,
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _validateAndClose,
                child: const Text('Enregistrer l ordre'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _move(int index, int offset) {
    final targetIndex = index + offset;
    if (targetIndex < 0 || targetIndex >= _members.length) {
      return;
    }

    final member = _members[index];
    final minimumTurn = member.minimumEligibleTurn ?? 1;
    if (targetIndex + 1 < minimumTurn) {
      return;
    }

    setState(() {
      final item = _members.removeAt(index);
      _members.insert(targetIndex, item);
    });
  }

  void _validateAndClose() {
    for (var index = 0; index < _members.length; index += 1) {
      final minimumTurn = _members[index].minimumEligibleTurn ?? 1;
      if (index + 1 < minimumTurn) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${_members[index].client?.displayName ?? 'Un membre'} ne peut pas etre place avant le tour $minimumTurn.',
              ),
            ),
          );
        return;
      }
    }

    Navigator.of(context).pop(_members.map((member) => member.id).toList());
  }
}

class _GroupMetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _GroupMetricItem({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: resolvedColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GroupTag extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _GroupTag({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagPalette {
  final Color foreground;
  final Color background;

  const _TagPalette({
    required this.foreground,
    required this.background,
  });
}

class _MenuSectionHeader extends PopupMenuItem<String> {
  _MenuSectionHeader({required String title})
      : super(
          enabled: false,
          height: 36,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667085),
            ),
          ),
        );
}
