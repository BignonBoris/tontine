import 'package:flutter/material.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';

class GoalCard extends StatelessWidget {
  final TontineGoal goal;

  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 160,
        height: 128,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: goal.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(goal.icon, color: goal.color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              goal.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              "${formatFCFA(goal.currentAmount.toInt())} F / ${formatFCFA(goal.targetAmount.toInt())} F",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Stack(
              children: [
                Container(
                  height: 5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  height: 5,
                  width: 122 * goal.progress,
                  decoration: BoxDecoration(
                    color: goal.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Progression",
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                Text(
                  "${(goal.progress * 100).toInt()}%",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: goal.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
