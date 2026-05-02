import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class GoalProgressIndicator extends StatelessWidget {
  final double percentage; // de 0.0 à 1.0

  const GoalProgressIndicator({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 50,
          width: 50,
          child: CircularProgressIndicator(
            value: percentage,
            strokeWidth: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppTheme.secondaryColor,
            ),
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          "${(percentage * 100).toInt()}%",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
