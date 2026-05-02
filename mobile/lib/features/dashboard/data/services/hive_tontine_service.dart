import 'package:hive/hive.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';

class HiveTontineService {
  final _box = Hive.box<TontineGoal>('goals_box');

  Future<List<TontineGoal>> getGoals() async {
    return _box.values.toList();
  }

  Future<void> addGoal(TontineGoal goal) async {
    await _box.put(goal.id, goal);
  }

  Future<void> updateGoal(TontineGoal goal) async {
    await goal.save(); // Grâce à extends HiveObject
  }
}
