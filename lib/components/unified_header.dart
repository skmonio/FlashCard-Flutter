import 'package:flutter/material.dart';

class UnifiedHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBack;
  final VoidCallback? onProfile;
  final Widget? trailing;
  final Color? backgroundColor;

  const UnifiedHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.onBack,
    this.onProfile,
    this.trailing,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Back button or profile button
              if (showBackButton && onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios),
                  iconSize: 20,
                )
              else if (onProfile != null)
                IconButton(
                  onPressed: onProfile,
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.grey[600], size: 20),
                  ),
                )
              else
                const SizedBox(width: 48),
              
              // Title
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Trailing widget or placeholder
              trailing ?? const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
} 