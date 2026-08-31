import 'package:flutter/material.dart';

/// Modèle représentant un coffre / box d'épargne suggéré par défaut
/// par l'administrateur lors de l'onboarding du client.
class GoalTemplate {
  final String id;
  final String label;
  final String? description;
  final int iconCodePoint;
  final int colorValue;
  final double? defaultTargetAmount;
  final int sortOrder;
  final bool isActive;

  const GoalTemplate({
    required this.id,
    required this.label,
    this.description,
    required this.iconCodePoint,
    required this.colorValue,
    this.defaultTargetAmount,
    this.sortOrder = 0,
    this.isActive = true,
  });

  IconData get iconData => IconData(
        iconCodePoint,
        fontFamily: 'MaterialIcons',
      );

  Color get color => Color(colorValue);

  factory GoalTemplate.fromJson(Map<String, dynamic> json) {
    return GoalTemplate(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      iconCodePoint: json['iconCodePoint'] is int
          ? json['iconCodePoint'] as int
          : int.tryParse(json['iconCodePoint']?.toString() ?? '') ?? 0xe87d,
      colorValue: json['colorValue'] is int
          ? json['colorValue'] as int
          : int.tryParse(json['colorValue']?.toString() ?? '') ?? 0xFF1565C0,
      defaultTargetAmount: json['defaultTargetAmount'] != null
          ? (json['defaultTargetAmount'] is num
              ? (json['defaultTargetAmount'] as num).toDouble()
              : double.tryParse(json['defaultTargetAmount'].toString()))
          : null,
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'defaultTargetAmount': defaultTargetAmount,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  /// Modèles de repli hors-ligne ou de démonstration si le réseau n'est pas encore disponible
  static List<GoalTemplate> get fallbackTemplates => const [
        GoalTemplate(
          id: 'fallback_school',
          label: 'École & Rentrée',
          description: 'Frais de scolarité, fournitures et tenues scolaires.',
          iconCodePoint: 0xe80c, // Icons.school
          colorValue: 0xFF1565C0,
          defaultTargetAmount: 50000,
          sortOrder: 1,
        ),
        GoalTemplate(
          id: 'fallback_trade',
          label: 'Commerce & Activité',
          description: 'Réapprovisionner votre boutique ou financer votre stock.',
          iconCodePoint: 0xe8d1, // Icons.store
          colorValue: 0xFF6A1B9A,
          defaultTargetAmount: 100000,
          sortOrder: 2,
        ),
        GoalTemplate(
          id: 'fallback_events',
          label: 'Fêtes & Cérémonies',
          description: 'Mariages, baptêmes, fêtes religieuses et événements.',
          iconCodePoint: 0xe8f6, // Icons.card_giftcard
          colorValue: 0xFFB45309,
          defaultTargetAmount: 25000,
          sortOrder: 3,
        ),
        GoalTemplate(
          id: 'fallback_home',
          label: 'Maison & Terrain',
          description: 'Achat de parcelle, matériaux ou travaux de rénovation.',
          iconCodePoint: 0xe88a, // Icons.home
          colorValue: 0xFF2E7D32,
          defaultTargetAmount: 500000,
          sortOrder: 4,
        ),
        GoalTemplate(
          id: 'fallback_emergency',
          label: 'Santé & Imprévus',
          description: 'Fonds de sécurité pour les urgences médicales du foyer.',
          iconCodePoint: 0xe8f3, // Icons.healing
          colorValue: 0xFFC62828,
          defaultTargetAmount: 20000,
          sortOrder: 5,
        ),
      ];
}
