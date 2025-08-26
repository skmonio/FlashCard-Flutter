import 'package:flutter/material.dart';
import '../models/learning_mastery.dart';

class QualityRatingWidget extends StatelessWidget {
  final Function(AnswerQuality) onQualitySelected;
  final bool showTitle;

  const QualityRatingWidget({
    super.key,
    required this.onQualitySelected,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle) ...[
            Text(
              'How well did you know this?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AnswerQuality.values.map((quality) {
              return _buildQualityButton(context, quality);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityButton(BuildContext context, AnswerQuality quality) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Define colors for each quality level
    Color getButtonColor() {
      switch (quality) {
        case AnswerQuality.completeBlackout:
          return Colors.red.shade400;
        case AnswerQuality.incorrect:
          return Colors.orange.shade400;
        case AnswerQuality.hard:
          return Colors.yellow.shade600;
        case AnswerQuality.good:
          return Colors.lightGreen.shade400;
        case AnswerQuality.easy:
          return Colors.green.shade400;
        case AnswerQuality.perfect:
          return Colors.green.shade600;
      }
    }

    Color getTextColor() {
      switch (quality) {
        case AnswerQuality.completeBlackout:
        case AnswerQuality.incorrect:
          return Colors.white;
        case AnswerQuality.hard:
          return isDark ? Colors.black : Colors.black;
        case AnswerQuality.good:
        case AnswerQuality.easy:
        case AnswerQuality.perfect:
          return Colors.white;
      }
    }

    String getLabel() {
      switch (quality) {
        case AnswerQuality.completeBlackout:
          return '0';
        case AnswerQuality.incorrect:
          return '1';
        case AnswerQuality.hard:
          return '2';
        case AnswerQuality.good:
          return '3';
        case AnswerQuality.easy:
          return '4';
        case AnswerQuality.perfect:
          return '5';
      }
    }

    String getTooltip() {
      switch (quality) {
        case AnswerQuality.completeBlackout:
          return 'Complete blank\nCouldn\'t recall at all';
        case AnswerQuality.incorrect:
          return 'Incorrect\nRemembered wrong';
        case AnswerQuality.hard:
          return 'Hard\nStruggled but got it';
        case AnswerQuality.good:
          return 'Good\nRecalled with effort';
        case AnswerQuality.easy:
          return 'Easy\nRecalled easily';
        case AnswerQuality.perfect:
          return 'Perfect\nImmediate recall';
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Tooltip(
          message: getTooltip(),
          child: ElevatedButton(
            onPressed: () => onQualitySelected(quality),
            style: ElevatedButton.styleFrom(
              backgroundColor: getButtonColor(),
              foregroundColor: getTextColor(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Text(
              getLabel(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Alternative widget for a more compact display
class CompactQualityRatingWidget extends StatelessWidget {
  final Function(AnswerQuality) onQualitySelected;

  const CompactQualityRatingWidget({
    super.key,
    required this.onQualitySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCompactButton(context, AnswerQuality.completeBlackout, '0', Colors.red),
        _buildCompactButton(context, AnswerQuality.incorrect, '1', Colors.orange),
        _buildCompactButton(context, AnswerQuality.hard, '2', Colors.yellow),
        _buildCompactButton(context, AnswerQuality.good, '3', Colors.lightGreen),
        _buildCompactButton(context, AnswerQuality.easy, '4', Colors.green),
        _buildCompactButton(context, AnswerQuality.perfect, '5', Colors.green.shade700),
      ],
    );
  }

  Widget _buildCompactButton(BuildContext context, AnswerQuality quality, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: ElevatedButton(
          onPressed: () => onQualitySelected(quality),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 1,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
