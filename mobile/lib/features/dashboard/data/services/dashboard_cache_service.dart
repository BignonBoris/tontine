import 'package:hive/hive.dart';
import 'package:mobile/features/dashboard/data/services/remote_dashboard_service.dart';

class CachedDashboardSnapshot {
  final RemoteDashboardSnapshot snapshot;
  final DateTime lastSyncedAt;

  const CachedDashboardSnapshot({
    required this.snapshot,
    required this.lastSyncedAt,
  });
}

class DashboardCacheService {
  static const String _boxName = 'dashboard_cache_box';
  static const String _snapshotKey = 'dashboard_snapshot';

  Box<dynamic>? get _box =>
      Hive.isBoxOpen(_boxName) ? Hive.box<dynamic>(_boxName) : null;

  Future<void> saveSnapshot(
    RemoteDashboardSnapshot snapshot, {
    required DateTime lastSyncedAt,
  }) async {
    final box = _box;
    if (box == null) {
      return;
    }

    await box.put(
      _snapshotKey,
      <String, dynamic>{
        'lastSyncedAt': lastSyncedAt.toIso8601String(),
        'snapshot': snapshot.toMap(),
      },
    );
  }

  Future<CachedDashboardSnapshot?> loadSnapshot() async {
    final box = _box;
    if (box == null) {
      return null;
    }

    final raw = box.get(_snapshotKey);
    if (raw is! Map) {
      return null;
    }

    final snapshotRaw = raw['snapshot'];
    final lastSyncedAt =
        DateTime.tryParse(raw['lastSyncedAt']?.toString() ?? '');
    if (snapshotRaw is! Map || lastSyncedAt == null) {
      return null;
    }

    return CachedDashboardSnapshot(
      snapshot: RemoteDashboardSnapshot.fromMap(
        Map<dynamic, dynamic>.from(snapshotRaw),
      ),
      lastSyncedAt: lastSyncedAt,
    );
  }

  Future<void> clear() async {
    final box = _box;
    if (box == null) {
      return;
    }

    await box.delete(_snapshotKey);
  }
}
