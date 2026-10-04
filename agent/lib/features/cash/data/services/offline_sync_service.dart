import 'dart:convert';

import 'package:agent/core/database/local_database_manager.dart';
import 'package:agent/core/services/network_time_service.dart';
import 'package:agent/features/history/data/models/offline_transaction_model.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

/// Exception raised when the device clock appears to have been manipulated.
///
/// An offline transaction must be refused when this exception is thrown, as
/// the timestamp cannot be trusted.
class ClockTamperingException implements Exception {
  final String message;
  const ClockTamperingException([
    this.message =
        "L'horloge de l'appareil est incorrecte. Reconnectez-vous pour corriger l'heure.",
  ]);

  @override
  String toString() => message;
}

/// Exception raised when the integrity of the local transaction chain is broken.
///
/// If the computed hash of any transaction does not match its stored hash,
/// a third-party script may have modified the local database between sessions.
/// Synchronization must be blocked immediately.
class ChainIntegrityException implements Exception {
  final List<String> corruptedIds;

  const ChainIntegrityException(this.corruptedIds);

  @override
  String toString() =>
      'Integrite de la chaine compromise: ${corruptedIds.join(', ')}';
}

class OfflineSyncService {
  static const String _boxName = 'offline_transactions';

  Future<Box<OfflineTransactionModel>> _getBox() async {
    return await LocalDatabaseManager.openEncryptedBox<OfflineTransactionModel>(
      _boxName,
    );
  }

  String _calculateHash(
    String previousHash,
    String id,
    double amount,
    DateTime timestamp,
  ) {
    final data = '$previousHash-$id-$amount-${timestamp.toIso8601String()}';
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString();
  }

  /// Records an offline transaction with a secure timestamp and a chained hash.
  ///
  /// Throws [ClockTamperingException] if the device clock appears manipulated.
  Future<OfflineTransactionModel> recordTransaction({
    required String id,
    required String type,
    required double amount,
    required String clientId,
  }) async {
    // ── Guard: reject if clock appears tampered ──────────────────────────────
    if (NetworkTimeService.instance.isSuspicious()) {
      throw const ClockTamperingException();
    }
    // ─────────────────────────────────────────────────────────────────────────

    final box = await _getBox();

    // Get the last transaction to form the chain (local blockchain)
    String previousHash = 'genesis_hash_00000000';
    if (box.isNotEmpty) {
      final lastTx = box.values.last;
      previousHash = lastTx.hash;
    }

    // Use the secure timestamp (referenced from last known server time)
    final timestamp = NetworkTimeService.instance.getSecureNow();
    final newHash = _calculateHash(previousHash, id, amount, timestamp);

    final transaction = OfflineTransactionModel(
      id: id,
      type: type,
      amount: amount,
      clientId: clientId,
      timestamp: timestamp,
      previousHash: previousHash,
      hash: newHash,
      isSynced: false,
    );

    await box.add(transaction);
    return transaction;
  }

  /// Returns all unsynced transactions, after verifying chain integrity.
  ///
  /// Throws [ChainIntegrityException] if any transaction's hash has been
  /// tampered with. The list of corrupted transaction IDs is included.
  Future<List<OfflineTransactionModel>> getUnsyncedTransactions() async {
    final box = await _getBox();
    final allTransactions = box.values.toList();

    // ── Verify chain integrity before returning anything ─────────────────────
    final corruptedIds = <String>[];
    String expectedPreviousHash = 'genesis_hash_00000000';

    for (final tx in allTransactions) {
      // Recompute the hash and compare
      final recomputedHash = _calculateHash(
        tx.previousHash,
        tx.id,
        tx.amount,
        tx.timestamp,
      );

      if (tx.hash != recomputedHash) {
        corruptedIds.add(tx.id);
      }

      // Also verify the chain link (previousHash matches previous tx's hash)
      if (tx.previousHash != expectedPreviousHash) {
        if (!corruptedIds.contains(tx.id)) {
          corruptedIds.add(tx.id);
        }
      }

      expectedPreviousHash = tx.hash;
    }

    if (corruptedIds.isNotEmpty) {
      throw ChainIntegrityException(corruptedIds);
    }
    // ─────────────────────────────────────────────────────────────────────────

    return allTransactions.where((tx) => !tx.isSynced).toList();
  }

  Future<void> markAsSynced(String id) async {
    final box = await _getBox();
    try {
      final tx = box.values.firstWhere((t) => t.id == id);
      tx.isSynced = true;
      await tx.save();
    } catch (e) {
      // Transaction not found
    }
  }
}
