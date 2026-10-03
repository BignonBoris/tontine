import 'package:agent/core/database/local_database_manager.dart';
import 'package:agent/features/clients/data/models/kyc_enrollment_model.dart';
import 'package:agent/core/network/api_client.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineKycService {
  static const String _boxName = 'kyc_enrollment_box';

  /// Ouvre la boîte chiffrée
  Future<Box<KycEnrollmentModel>> _getBox() async {
    return await LocalDatabaseManager.openEncryptedBox<KycEnrollmentModel>(_boxName);
  }

  /// Sauvegarde un nouveau dossier KYC en local
  Future<KycEnrollmentModel> saveEnrollment({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String pinCode,
    required double stakeAmount,
    String? documentType,
    String? documentNumber,
    String? frontImagePath,
    String? backImagePath,
    String? selfiePath,
  }) async {
    final box = await _getBox();
    
    // Génération d'un ID temporaire pour la synchro
    final localId = const Uuid().v4();

    final model = KycEnrollmentModel(
      clientId: localId,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      pinCode: pinCode,
      documentType: documentType,
      documentNumber: documentNumber,
      frontImageFilePath: frontImagePath,
      backImageFilePath: backImagePath,
      selfieFilePath: selfiePath,
      stakeAmount: stakeAmount,
      syncStatus: 'pending',
      createdAt: DateTime.now(),
    );

    await box.put(model.clientId, model);
    return model;
  }

  /// Récupère tous les enrôlements en attente de synchronisation
  Future<List<KycEnrollmentModel>> getPendingEnrollments() async {
    final box = await _getBox();
    return box.values.where((e) => e.syncStatus == 'pending').toList();
  }

  /// Marque un dossier comme synchronisé
  Future<void> markAsSynced(String clientId) async {
    final box = await _getBox();
    final model = box.get(clientId);
    if (model != null) {
      // Dans une vraie app avec Freezed/copy, on ferait un copyWith.
      // Avec Hive généré on peut modifier et save, ou recréer.
      final updated = KycEnrollmentModel(
        clientId: model.clientId,
        firstName: model.firstName,
        lastName: model.lastName,
        phoneNumber: model.phoneNumber,
        documentType: model.documentType,
        documentNumber: model.documentNumber,
        frontImageFilePath: model.frontImageFilePath,
        backImageFilePath: model.backImageFilePath,
        selfieFilePath: model.selfieFilePath,
        syncStatus: 'synced',
        createdAt: model.createdAt,
        pinCode: model.pinCode,
        stakeAmount: model.stakeAmount,
      );
      await box.put(clientId, updated);
    }
  }

  /// Supprime un dossier KYC (par ex. après synchro ou annulation)
  Future<void> deleteEnrollment(String clientId) async {
    final box = await _getBox();
    await box.delete(clientId);
  }

  /// Synchronise les dossiers en attente avec le backend
  Future<void> syncPendingEnrollments(ApiClient apiClient) async {
    final pendingList = await getPendingEnrollments();
    if (pendingList.isEmpty) return;

    for (final enrollment in pendingList) {
      try {
        // 1. Création du client (Niveau 0)
        final createResponse = await apiClient.post(
          '/agent/clients',
          body: {
            'firstName': enrollment.firstName,
            'lastName': enrollment.lastName,
            'phoneNumber': enrollment.phoneNumber,
            'pinCode': enrollment.pinCode,
            'address': 'Non spécifiée', // Valeur par défaut
            'stakeAmount': enrollment.stakeAmount,
            'initialDeposit': 0,
          },
        );

        final clientId = createResponse['id'];

        // 2. Upload des documents KYC si Niveau 1 activé
        if (enrollment.documentType != null && clientId != null) {
          final filePaths = <String, String>{};
          if (enrollment.frontImageFilePath != null) {
            filePaths['front'] = enrollment.frontImageFilePath!;
          }
          if (enrollment.backImageFilePath != null) {
            filePaths['back'] = enrollment.backImageFilePath!;
          }
          if (enrollment.selfieFilePath != null) {
            filePaths['selfie'] = enrollment.selfieFilePath!;
          }

          await apiClient.postMultipart(
            '/agent/clients/$clientId/kyc',
            fields: {
              'documentType': enrollment.documentType!,
              'documentNumber': enrollment.documentNumber ?? '',
              'countryCode': 'BJ',
            },
            filePaths: filePaths,
          );
        }

        // Marquer comme synchronisé
        await markAsSynced(enrollment.clientId);
      } catch (e) {
        print('Erreur lors de la synchronisation de \${enrollment.clientId}: $e');
        // On continue avec le suivant, on ne bloque pas la boucle
      }
    }
  }
}
