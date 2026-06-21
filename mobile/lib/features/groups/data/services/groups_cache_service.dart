import 'package:hive/hive.dart';
import 'package:mobile/features/groups/domain/entities/client_group_advance.dart';
import 'package:mobile/features/groups/domain/entities/client_group_advance_recovery.dart';
import 'package:mobile/features/groups/domain/entities/client_group_contribution.dart';
import 'package:mobile/features/groups/domain/entities/client_group_membership.dart';
import 'package:mobile/features/groups/domain/entities/group_invitation_preview.dart';

class GroupsCacheService {
  static const String _boxName = 'groups_cache_box';
  static const String _myGroupsKey = 'my_groups';
  static const String _myGroupRequestsKey = 'my_group_requests';
  static const String _pendingInvitationsKey = 'pending_invitations';

  Box<dynamic>? get _box =>
      Hive.isBoxOpen(_boxName) ? Hive.box<dynamic>(_boxName) : null;

  Future<void> saveMyGroups(List<ClientGroupMembership> groups) {
    return _saveList(_myGroupsKey, groups, (group) => group.toMap());
  }

  Future<List<ClientGroupMembership>?> loadMyGroups() {
    return _loadList(_myGroupsKey, ClientGroupMembership.fromMap);
  }

  Future<void> saveMyGroupRequests(List<ClientGroupMembership> groups) {
    return _saveList(_myGroupRequestsKey, groups, (group) => group.toMap());
  }

  Future<List<ClientGroupMembership>?> loadMyGroupRequests() {
    return _loadList(_myGroupRequestsKey, ClientGroupMembership.fromMap);
  }

  Future<void> saveGroupDetail(
    String groupId,
    ClientGroupMembership group,
  ) async {
    await _put(_groupDetailKey(groupId), group.toMap());
  }

  Future<ClientGroupMembership?> loadGroupDetail(String groupId) async {
    final direct = await _loadItem(
      _groupDetailKey(groupId),
      ClientGroupMembership.fromMap,
    );
    if (direct != null) {
      return direct;
    }

    final groups = await loadMyGroups();
    final requests = await loadMyGroupRequests();
    final candidates = <ClientGroupMembership>[
      if (groups != null) ...groups,
      if (requests != null) ...requests,
    ];

    for (final group in candidates) {
      if (group.id == groupId) {
        return group;
      }
    }

    return null;
  }

  Future<void> saveGroupContributions(
    String groupId,
    List<ClientGroupContribution> contributions,
  ) {
    return _saveList(
      _groupContributionsKey(groupId),
      contributions,
      (item) => item.toMap(),
    );
  }

  Future<List<ClientGroupContribution>?> loadGroupContributions(
    String groupId,
  ) {
    return _loadList(
      _groupContributionsKey(groupId),
      ClientGroupContribution.fromMap,
    );
  }

  Future<void> saveGroupAdvances(
    String groupId,
    List<ClientGroupAdvance> advances,
  ) {
    return _saveList(
      _groupAdvancesKey(groupId),
      advances,
      (item) => item.toMap(),
    );
  }

  Future<List<ClientGroupAdvance>?> loadGroupAdvances(String groupId) {
    return _loadList(
      _groupAdvancesKey(groupId),
      ClientGroupAdvance.fromMap,
    );
  }

  Future<void> saveGroupAdvanceRecoveries(
    String groupId,
    List<ClientGroupAdvanceRecovery> recoveries,
  ) {
    return _saveList(
      _groupRecoveriesKey(groupId),
      recoveries,
      (item) => item.toMap(),
    );
  }

  Future<List<ClientGroupAdvanceRecovery>?> loadGroupAdvanceRecoveries(
    String groupId,
  ) {
    return _loadList(
      _groupRecoveriesKey(groupId),
      ClientGroupAdvanceRecovery.fromMap,
    );
  }

  Future<void> savePendingInvitations(
    List<GroupInvitationPreview> invitations,
  ) async {
    final serialized =
        invitations.map((invitation) => invitation.toMap()).toList();
    await _put(_pendingInvitationsKey, serialized);

    for (final invitation in invitations) {
      await _put(_invitationPreviewKey(invitation.token), invitation.toMap());
    }
  }

  Future<List<GroupInvitationPreview>?> loadPendingInvitations() {
    return _loadList(
      _pendingInvitationsKey,
      GroupInvitationPreview.fromMap,
    );
  }

  Future<void> saveInvitationPreview(GroupInvitationPreview preview) async {
    await _put(_invitationPreviewKey(preview.token), preview.toMap());
  }

  Future<GroupInvitationPreview?> loadInvitationPreview(String token) {
    return _loadItem(
      _invitationPreviewKey(token),
      GroupInvitationPreview.fromMap,
    );
  }

  Future<void> removePendingInvitation(String token) async {
    final box = _box;
    if (box == null) {
      return;
    }

    final invitations = await loadPendingInvitations();
    if (invitations != null) {
      await box.put(
        _pendingInvitationsKey,
        invitations.where((invitation) => invitation.token != token).map(
              (invitation) => invitation.toMap(),
            ).toList(),
      );
    }

    await box.delete(_invitationPreviewKey(token));
  }

  Future<void> clear() async {
    final box = _box;
    if (box == null) {
      return;
    }

    await box.clear();
  }

  Future<void> _saveList<T>(
    String key,
    List<T> items,
    Map<String, dynamic> Function(T item) toMap,
  ) async {
    final box = _box;
    if (box == null) {
      return;
    }

    await box.put(key, items.map(toMap).toList());
  }

  Future<List<T>?> _loadList<T>(
    String key,
    T Function(Map<dynamic, dynamic> map) fromMap,
  ) async {
    final box = _box;
    if (box == null || !box.containsKey(key)) {
      return null;
    }

    final raw = box.get(key);
    if (raw is! List) {
      return null;
    }

    return raw
        .whereType<Map>()
        .map((entry) => fromMap(Map<dynamic, dynamic>.from(entry)))
        .toList();
  }

  Future<T?> _loadItem<T>(
    String key,
    T Function(Map<dynamic, dynamic> map) fromMap,
  ) async {
    final box = _box;
    if (box == null || !box.containsKey(key)) {
      return null;
    }

    final raw = box.get(key);
    if (raw is! Map) {
      return null;
    }

    return fromMap(Map<dynamic, dynamic>.from(raw));
  }

  Future<void> _put(String key, dynamic value) async {
    final box = _box;
    if (box == null) {
      return;
    }

    await box.put(key, value);
  }

  static String _groupDetailKey(String groupId) => 'group_detail_$groupId';

  static String _groupContributionsKey(String groupId) =>
      'group_contributions_$groupId';

  static String _groupAdvancesKey(String groupId) => 'group_advances_$groupId';

  static String _groupRecoveriesKey(String groupId) =>
      'group_recoveries_$groupId';

  static String _invitationPreviewKey(String token) =>
      'invitation_preview_$token';
}
