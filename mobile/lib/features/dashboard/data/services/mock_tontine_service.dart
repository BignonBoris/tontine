import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';

class MockTontineService {
  Future<List<TontineGoal>> fetchUserGoals() async {
    await Future.delayed(const Duration(seconds: 1));

    final double randomBonus = Random().nextInt(1000).toDouble();
    final DateTime now = DateTime.now();

    return [
      TontineGoal(
        id: "1",
        title: "Moto Cheetah",
        targetAmount: 500000,
        currentAmount: 125000 + randomBonus,
        // On passe le codePoint de l'icône au lieu de l'objet IconData
        iconCodePoint: Icons.motorcycle_rounded.codePoint,
        // On passe la valeur entière de la couleur
        colorValue: const Color(0xFF1A237E).value,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 60)),
      ),
      TontineGoal(
        id: "2",
        title: "Scolarité Sept",
        targetAmount: 100000,
        currentAmount: 85000,
        iconCodePoint: Icons.school_rounded.codePoint,
        colorValue: const Color(0xFF00C853).value,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 5)),
      ),
      TontineGoal(
        id: "3",
        title: "Épargne Urgence",
        targetAmount: 200000,
        currentAmount: 45000,
        iconCodePoint: Icons.shield_rounded.codePoint,
        colorValue: const Color(0xFFFFAB00).value,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.add(const Duration(days: 365)),
      ),
    ];
  }
}
