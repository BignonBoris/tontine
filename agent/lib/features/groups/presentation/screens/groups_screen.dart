import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/groups/data/services/agent_group_service.dart';
import 'package:agent/features/groups/domain/entities/agent_group.dart';
import 'package:agent/features/groups/presentation/screens/agent_group_enrollment_screen.dart';
import 'package:agent/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_form_sheet.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_list_tile.dart';
import 'package:agent/core/theme/agent_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _service = AgentGroupService();
  final _searchController = TextEditingController();
  String _status = 'all';
  bool _showSearchCard = false;
  late Future<List<AgentGroup>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _service.fetchGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _groupsFuture = _service.fetchGroups(
        query: _searchController.text,
        status: _status,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Groupes'),
        actions: [
          IconButton(
            onPressed: _toggleSearchCard,
            icon: Icon(
              _showSearchCard ? Icons.search_off_rounded : Icons.search_rounded,
            ),
            tooltip: _showSearchCard
                ? 'Masquer la recherche'
                : 'Rechercher un groupe',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_showSearchCard) ...[
              SoftSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => _reload(),
                      decoration: const InputDecoration(
                        labelText: 'Nom ou reference',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Statut',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tous')),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Actifs'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('Suspendus'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _status = value ?? 'all';
                        });
                        _reload();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            FutureBuilder<List<AgentGroup>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 240,
                    child: AgentLoadingView(
                      message: 'Chargement de vos groupes terrain...',
                    ),
                  );
                }

                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is ApiException
                      ? error.message
                      : 'Impossible de charger les groupes.';
                  return SizedBox(
                    height: 260,
                    child: AgentErrorView(
                      title: 'Groupes indisponibles',
                      message: message,
                      onRetry: _reload,
                    ),
                  );
                }

                final groups = snapshot.data ?? const <AgentGroup>[];
                final totalGroups = groups.length;
                final activeGroups = groups.where((g) => g.isActive).length;

                if (groups.isEmpty) {
                  return const SizedBox(
                    height: 260,
                    child: AgentEmptyView(
                      icon: Icons.groups_2_outlined,
                      title: 'Aucun groupe enregistre',
                      message:
                          'Creez un groupe agent pour preparer les prochaines operations collectives.',
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '$activeGroups actif${activeGroups > 1 ? 's' : ''} · $totalGroups groupe${totalGroups > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    ...groups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AgentGroupListTile(
                            group: group,
                            onTap: () => _showGroupActionsSheet(group),
                            trailing: null,
                          ),
                        ),
                      )
                      .toList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'groups_add_fab',
        onPressed: _openCreateSheet,
        shape: const CircleBorder(),
        child: const Icon(Icons.group_add_rounded),
      ),
    );
  }

  void _showGroupActionsSheet(AgentGroup group) {
    // Construire la liste d'actions disponibles
    final actions = <Map<String, dynamic>>[
      {
        'value': 'detail',
        'label': 'Voir le détail du groupe',
        'icon': Icons.visibility_outlined,
        'color': AgentAppTheme.primaryColor,
      },
    ];

    if (!group.isStarted &&
        group.status == 'active' &&
        group.launchStatus != 'launch_cancelled') {
      actions.add({
        'value': 'launch',
        'label': 'Lancer la tontine',
        'icon': Icons.play_circle_outline_rounded,
        'color': AgentAppTheme.successColor,
      });
    }

    if (!group.isStarted) {
      actions.addAll([
        {
          'value': 'edit',
          'label': 'Modifier le groupe',
          'icon': Icons.edit_outlined,
          'color': AgentAppTheme.primaryColor,
        },
        {
          'value': 'postpone',
          'label': 'Prolonger la date de lancement',
          'icon': Icons.calendar_month_outlined,
          'color': AgentAppTheme.accentColor,
        },
        {
          'value': 'reduce_target',
          'label': 'Réduire à l\'effectif actuel',
          'icon': Icons.group_remove_outlined,
          'color': Colors.orange,
        },
        {
          'value': 'cancel_launch',
          'label': 'Annuler le lancement',
          'icon': Icons.cancel_outlined,
          'color': AgentAppTheme.errorColor,
        },
      ]);
    }

    actions.add({
      'value': group.isActive ? 'suspend' : 'activate',
      'label': group.isActive ? 'Suspendre le groupe' : 'Réactiver le groupe',
      'icon': group.isActive ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded,
      'color': group.isActive ? Colors.orange : AgentAppTheme.successColor,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AgentAppTheme.textPrimaryColor,
                            ),
                          ),
                          Text(
                            'Choisissez une action',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AgentAppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Liste des actions scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...actions.map((action) => ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: (action['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            color: action['color'] as Color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          action['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AgentAppTheme.textPrimaryColor,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AgentAppTheme.textSecondaryColor,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _handleGroupAction(action['value'] as String, group);
                          });
                        },
                      )),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearchCard() {
    setState(() {
      _showSearchCard = !_showSearchCard;
    });
  }

  Future<void> _openCreateSheet() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgentGroupEnrollmentScreen()),
    );

    if (!mounted || result != true) {
      return;
    }

    _reload();
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

  Future<void> _openGroupDetail(AgentGroup group) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupDetailScreen(groupId: group.id),
      ),
    );
    if (mounted) {
      _reload();
    }
  }

  Future<void> _handleGroupAction(String action, AgentGroup group) async {
    switch (action) {
      case 'detail':
        await _openGroupDetail(group);
        return;
      case 'launch':
        await _launchGroup(group);
        return;
      case 'postpone':
        await _postponeGroup(group);
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
    }
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

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
