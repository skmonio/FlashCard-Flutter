import 'package:flutter/material.dart';

/// Row of heart icons showing remaining lives.
class GameLivesIndicator extends StatelessWidget {
  final int lives;
  final int maxLives;

  const GameLivesIndicator({
    super.key,
    required this.lives,
    required this.maxLives,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            index < lives ? Icons.favorite : Icons.favorite_border,
            color: Colors.red,
            size: 18,
          ),
        );
      }),
    );
  }
}

/// Color-coded countdown timer display (green → orange → red).
class GameTimerIndicator extends StatelessWidget {
  final int timeRemaining;
  final int totalTime;

  const GameTimerIndicator({
    super.key,
    required this.timeRemaining,
    required this.totalTime,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalTime > 0 ? timeRemaining / totalTime : 0.0;
    final Color timerColor;
    if (progress < 0.3) {
      timerColor = Colors.red;
    } else if (progress < 0.6) {
      timerColor = Colors.orange;
    } else {
      timerColor = Colors.green;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer, color: timerColor, size: 18),
        const SizedBox(width: 6),
        Text(
          '$timeRemaining',
          style: TextStyle(
            color: timerColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
