import 'package:agent/core/network/api_client.dart';
import 'package:agent/core/widgets/agent_state_views.dart';
import 'package:agent/core/widgets/soft_section_card.dart';
import 'package:agent/features/auth/presentation/widgets/agent_logout_action.dart';
import 'package:agent/features/groups/data/services/agent_group_service.dart';
import 'package:agent/features/groups/domain/entities/agent_group.dart';
import 'package:agent/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_form_sheet.dart';
import 'package:agent/features/groups/presentation/widgets/agent_group_list_tile.dart';
import 'package:flutter/material.dart';

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
              _showSearchCard
                  ? Icons.search_off_rounded
                  : Icons.search_rounded,
            ),
            tooltip: _showSearchCard
                ? 'Masquer la recherche'
                : 'Rechercher un groupe',
          ),
          const AgentLogoutAction(),
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
                        DropdownMenuItem(value: 'active', child: Text('Actifs')),
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
                  children: groups
                      .map(
                        (group) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AgentGroupListTile(
                            group: group,
                            onTap: () => _openGroupDetail(group),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) =>
                                  _handleGroupAction(value, group),
                              itemBuilder: (context) => _buildActions(group),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'groups_add_fab',
        onPressed: _openCreateSheet,
        label: const Text('Ajouter'),
        icon: const Icon(Icons.group_add_rounded),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildActions(AgentGroup group) {
    final items = <PopupMenuEntry<String>>[];

    if (!group.isStarted &&
        group.status == 'active' &&
        group.launchStatus != 'launch_cancelled') {
      items.add(
        const PopupMenuItem<String>(
          value: 'launch',
          child: Text('Lancer la tontine'),
        ),
      );
    }

    if (!group.isStarted) {
      items.addAll(const [
        PopupMenuItem<String>(
          value: 'postpone',
          child: Text('Prolonger la date'),
        ),
        PopupMenuItem<String>(
          value: 'reduce_target',
          child: Text('Reduire a l effectif actuel'),
        ),
        PopupMenuItem<String>(
          value: 'cancel_launch',
          child: Text('Annuler le lancement'),
        ),
      ]);
    }

    if (!group.isStarted) {
      items.add(
        const PopupMenuItem<String>(value: 'edit', child: Text('Modifier')),
      );
    }
    items.add(
      PopupMenuItem<String>(
        value: group.isActive ? 'suspend' : 'activate',
        child: Text(group.isActive ? 'Suspendre' : 'Reactiver'),
      ),
    );
    return items;
  }

  void _toggleSearchCard() {
    setState(() {
      _showSearchCard = !_showSearchCard;
    });
  }

  Future<void> _openCreateSheet() async {
    final result = await showModalBottomSheet<AgentGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AgentGroupFormSheet(),
    );

    if (!mounted || result == null) {
      return;
    }

    _reload();
    _showMessage('Groupe cree avec succes.');
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
