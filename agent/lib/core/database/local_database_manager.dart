import 'package:hive_flutter/hive_flutter.dart';
import 'package:agent/core/security/secure_storage_service.dart';
import 'package:agent/features/history/data/models/offline_transaction_model.dart';
import 'package:agent/features/clients/data/models/kyc_enrollment_model.dart';

class LocalDatabaseManager {
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Les adapters pour les modèles seront enregistrés ici
    Hive.registerAdapter(OfflineTransactionModelAdapter());
    Hive.registerAdapter(KycEnrollmentModelAdapter());
  }

  /// Ouvre une boîte Hive de manière sécurisée en utilisant la clé AES générée.
  static Future<Box<E>> openEncryptedBox<E>(String boxName) async {
    final encryptionKey = await SecureStorageService.getEncryptionKey();
    
    return await Hive.openBox<E>(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  }
}
