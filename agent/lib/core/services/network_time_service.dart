import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service responsible for managing a trusted network time reference.
///
/// The device clock can be manipulated by an agent to backdate transactions.
/// This service stores the last known server time at each successful API call,
/// then computes a "secure now" by adding the elapsed monotonic time since capture.
///
/// If the local clock deviates more than [_maxAllowedDriftMinutes] from the
/// secure reference, [isSuspicious] returns true and all offline transactions
/// must be refused.
class NetworkTimeService {
  NetworkTimeService._();

  static final NetworkTimeService instance = NetworkTimeService._();

  static const _storage = FlutterSecureStorage();
  static const _keyLastNetworkTime = 'last_network_time_utc';
  static const _keyLastLocalCapture = 'last_local_capture_utc';

  /// Maximum drift in minutes tolerated between the device clock and the
  /// last known server time. Beyond this threshold, the clock is considered
  /// tampered with.
  static const int _maxAllowedDriftMinutes = 10;

  // In-memory references for performance (avoids reading secure storage on each call)
  DateTime? _lastNetworkTime;
  DateTime? _lastLocalCapture;

  /// Called by [ApiClient] whenever a successful HTTP response is received.
  ///
  /// [serverTime] should be parsed from the `Date:` HTTP response header.
  Future<void> updateFromServerTime(DateTime serverTime) async {
    final localNow = DateTime.now().toUtc();

    _lastNetworkTime = serverTime.toUtc();
    _lastLocalCapture = localNow;

    await _storage.write(
      key: _keyLastNetworkTime,
      value: _lastNetworkTime!.toIso8601String(),
    );
    await _storage.write(
      key: _keyLastLocalCapture,
      value: _lastLocalCapture!.toIso8601String(),
    );
  }

  /// Restores the in-memory references from secure storage.
  ///
  /// Should be called once at app startup (in [LocalDatabaseManager.init] or
  /// equivalent) so the service is ready even if [updateFromServerTime] hasn't
  /// been called yet in this session.
  Future<void> loadFromStorage() async {
    final networkStr = await _storage.read(key: _keyLastNetworkTime);
    final captureStr = await _storage.read(key: _keyLastLocalCapture);

    if (networkStr != null) {
      _lastNetworkTime = DateTime.tryParse(networkStr)?.toUtc();
    }
    if (captureStr != null) {
      _lastLocalCapture = DateTime.tryParse(captureStr)?.toUtc();
    }
  }

  /// Returns the estimated current UTC time based on the last trusted network
  /// reference, using the device's monotonic elapsed time.
  ///
  /// Falls back to [DateTime.now()] if no reference is available (first run).
  DateTime getSecureNow() {
    if (_lastNetworkTime == null || _lastLocalCapture == null) {
      // No reference yet — fall back to local time (first run / no connectivity ever)
      return DateTime.now().toUtc();
    }

    final elapsed = DateTime.now().toUtc().difference(_lastLocalCapture!);
    return _lastNetworkTime!.add(elapsed);
  }

  /// Returns true if the local clock appears to have been tampered with.
  ///
  /// Specifically: if the absolute drift between [DateTime.now()] and
  /// [getSecureNow()] exceeds [_maxAllowedDriftMinutes], the clock is
  /// considered manipulated.
  bool isSuspicious() {
    if (_lastNetworkTime == null || _lastLocalCapture == null) {
      // Cannot determine — allow to avoid false positives on first use
      return false;
    }

    final secureNow = getSecureNow();
    final localNow = DateTime.now().toUtc();
    final drift = localNow.difference(secureNow).abs();

    return drift.inMinutes > _maxAllowedDriftMinutes;
  }

  /// Returns a human-readable description of the current drift, for logging.
  String driftDescription() {
    if (_lastNetworkTime == null) return 'no reference';
    final drift = DateTime.now().toUtc().difference(getSecureNow());
    return '${drift.inSeconds}s drift';
  }

  /// Clears all stored time references (call on logout).
  Future<void> clear() async {
    _lastNetworkTime = null;
    _lastLocalCapture = null;
    await _storage.delete(key: _keyLastNetworkTime);
    await _storage.delete(key: _keyLastLocalCapture);
  }
}
