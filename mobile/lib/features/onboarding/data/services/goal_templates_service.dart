import 'package:flutter/foundation.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/onboarding/domain/entities/goal_template.dart';

class GoalTemplatesResponse {
  final List<GoalTemplate> templates;
  final bool onboardingCompleted;

  const GoalTemplatesResponse({
    required this.templates,
    required this.onboardingCompleted,
  });
}

class GoalTemplatesService {
  final ApiClient _apiClient;

  GoalTemplatesService({ApiClient? apiClient})
      : _apiClient = apiClient ??
            ApiClient(invalidateSessionOnUnauthorized: false);

  /// Récupère la liste des coffres par défaut disponibles depuis l'API
  Future<GoalTemplatesResponse> fetchActiveTemplates() async {
    try {
      final dynamic response = await _apiClient.get('/goal-templates');

      if (response is Map<String, dynamic>) {
        final rawTemplates = response['templates'] as List<dynamic>? ?? [];
        final onboardingCompleted =
            response['onboardingCompleted'] as bool? ?? false;

        final templates = rawTemplates
            .map((item) =>
                GoalTemplate.fromJson(item as Map<String, dynamic>))
            .where((t) => t.isActive)
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        return GoalTemplatesResponse(
          templates: templates.isNotEmpty
              ? templates
              : GoalTemplate.fallbackTemplates,
          onboardingCompleted: onboardingCompleted,
        );
      }

      return GoalTemplatesResponse(
        templates: GoalTemplate.fallbackTemplates,
        onboardingCompleted: false,
      );
    } catch (e, stack) {
      debugPrint('[GoalTemplatesService] ⚠️ Erreur fetchActiveTemplates: $e');
      debugPrint('[GoalTemplatesService] Stack: $stack');
      // En cas de coupure ou d'erreur réseau, renvoyer les templates de repli
      return GoalTemplatesResponse(
        templates: GoalTemplate.fallbackTemplates,
        onboardingCompleted: false,
      );
    }
  }

  /// Applique la sélection des 1 à 3 coffres choisis par le client
  Future<bool> applyTemplates(List<String> templateIds) async {
    if (templateIds.isEmpty) {
      return false;
    }

    try {
      final dynamic response = await _apiClient.post(
        '/goal-templates/apply',
        body: {
          'templateIds': templateIds,
        },
      );

      if (response is Map<String, dynamic>) {
        final count = response['createdCount'] as int? ?? 0;
        return count > 0;
      }
      return true;
    } catch (e) {
      debugPrint('[GoalTemplatesService] Erreur applyTemplates: $e');
      // Si l'erreur est un 409 (déjà configuré), on considère l'étape validée
      if (e is ApiException && e.statusCode == 409) {
        return true;
      }
      rethrow;
    }
  }
}
