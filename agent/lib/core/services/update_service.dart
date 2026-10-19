import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:agent/core/network/api_config.dart';

/// Modèle des données retournées par l'endpoint /app-version/agent
class AppVersionInfo {
  final String version;
  final int build;
  final bool mandatory;
  final int minBuild;
  final String downloadUrl;
  final String releaseNotes;
  final String releasedAt;

  const AppVersionInfo({
    required this.version,
    required this.build,
    required this.mandatory,
    required this.minBuild,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releasedAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: json['version'] as String? ?? '',
      build: _asInt(json['build']),
      mandatory: json['mandatory'] == true,
      minBuild: _asInt(json['min_build']),
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      releasedAt: json['released_at'] as String? ?? '',
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }
}

/// Résultat de la vérification de mise à jour
class UpdateCheckResult {
  /// Une mise à jour est disponible
  final bool updateAvailable;

  /// La mise à jour est obligatoire (bloque l'app)
  final bool isMandatory;

  /// Infos de la nouvelle version
  final AppVersionInfo? serverVersion;

  /// Build actuel de l'app installée
  final int currentBuild;

  const UpdateCheckResult({
    required this.updateAvailable,
    required this.isMandatory,
    required this.currentBuild,
    this.serverVersion,
  });
}

/// Service de mise à jour OTA.
/// Vérifie si une nouvelle version est disponible et gère le téléchargement
/// + installation de l'APK sans passer par le Play Store.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  final Dio _dio = Dio();

  // ── Vérification de version ──────────────────────────────────────────────────

  /// Interroge l'API et compare avec la version installée.
  /// Retourne null en cas d'erreur réseau (on ne bloque pas l'app pour ça).
  Future<UpdateCheckResult?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await _dio
          .get('${ApiConfig.baseUrl}/app-version/agent')
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      final serverInfo = AppVersionInfo.fromJson(data);

      // Sans lien de téléchargement, il n'y a rien à proposer.
      final updateAvailable = serverInfo.build > currentBuild &&
          serverInfo.downloadUrl.isNotEmpty;
      // Obligatoire si le build actuel est inférieur au build minimum requis
      final isMandatory =
          serverInfo.mandatory || currentBuild < serverInfo.minBuild;

      debugPrint(
        '[UpdateService] current=$currentBuild server=${serverInfo.build} '
        'updateAvailable=$updateAvailable mandatory=$isMandatory',
      );

      return UpdateCheckResult(
        updateAvailable: updateAvailable,
        isMandatory: updateAvailable && isMandatory,
        currentBuild: currentBuild,
        serverVersion: serverInfo,
      );
    } catch (e) {
      debugPrint('[UpdateService] Vérification échouée (ignorée) : $e');
      return null;
    }
  }

  // ── Téléchargement & Installation ───────────────────────────────────────────

  /// Télécharge l'APK depuis [downloadUrl] avec suivi de progression.
  /// [onProgress] reçoit un double entre 0.0 et 1.0.
  /// Retourne le chemin du fichier téléchargé, ou null en cas d'échec.
  Future<String?> downloadApk(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Sur Android, demander la permission d'installer des APK inconnus
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          debugPrint('[UpdateService] Permission REQUEST_INSTALL_PACKAGES refusée');
          return null;
        }
      }

      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/agent_update.apk';

      await _dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      return savePath;
    } catch (e) {
      debugPrint('[UpdateService] Échec du téléchargement : $e');
      return null;
    }
  }

  /// Lance l'installation de l'APK situé à [filePath].
  Future<void> installApk(String filePath) async {
    final result = await OpenFile.open(filePath, type: 'application/vnd.android.package-archive');
    debugPrint('[UpdateService] OpenFile result: ${result.message}');
  }
}
