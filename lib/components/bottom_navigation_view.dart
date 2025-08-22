import 'package:flutter/material.dart';

class BottomNavigationView extends StatelessWidget {
  final int selectedTabIndex;
  final Function(int) onTabChanged;

  const BottomNavigationView({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Separator line
            Container(
              height: 0.5,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
            // Tab buttons with flexible height
            Container(
              height: 60,
              child: Row(
                                       children: [
                         _buildTabButton(context, 0, Icons.home, 'Home'),
                         _buildTabButton(context, 1, Icons.folder, 'Cards'),
                         _buildTabButton(context, 2, Icons.settings, 'Settings'),
                       ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final isSelected = selectedTabIndex == index;
    final color = isSelected 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Expanded(
      child: InkWell(
        onTap: () => onTabChanged(index),
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
              ),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 