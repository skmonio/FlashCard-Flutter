import 'package:flutter/material.dart';

class HPBar extends StatelessWidget {
  final int currentHP;
  final int maxHP;
  final double? width;
  final double? height;
  final bool showText;
  final bool showStatus;

  const HPBar({
    Key? key,
    required this.currentHP,
    required this.maxHP,
    this.width,
    this.height = 8.0,
    this.showText = true,
    this.showStatus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hpPercentage = currentHP / maxHP;
    final isDefeated = currentHP <= 0;
    
    // Determine HP bar color based on percentage
    Color hpColor;
    if (isDefeated) {
      hpColor = Colors.grey[600]!;
    } else if (hpPercentage > 0.6) {
      hpColor = Colors.green[600]!;
    } else if (hpPercentage > 0.3) {
      hpColor = Colors.orange[600]!;
    } else {
      hpColor = Colors.red[600]!;
    }

    // Get HP status text
    String hpStatusText;
    if (currentHP == maxHP) {
      hpStatusText = 'Full Health';
    } else if (currentHP > maxHP * 0.6) {
      hpStatusText = 'Healthy';
    } else if (currentHP > maxHP * 0.3) {
      hpStatusText = 'Wounded';
    } else if (currentHP > 0) {
      hpStatusText = 'Critical';
    } else {
      hpStatusText = 'Defeated';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showText || showStatus) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (showText) ...[
                Row(
                  children: [
                    Icon(
                      isDefeated ? Icons.block : Icons.favorite,
                      size: 16,
                      color: hpColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'HP: $currentHP/$maxHP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hpColor,
                      ),
                    ),
                  ],
                ),
              ],
              if (showStatus) ...[
                Text(
                  hpStatusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hpColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
        ],
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height! / 2),
            color: Colors.grey[300],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: hpPercentage.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height! / 2),
                color: hpColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
