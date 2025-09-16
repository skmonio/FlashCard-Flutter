import 'package:flutter/material.dart';

/// Enhanced SnackBar with swipe-to-dismiss and cross-to-dismiss functionality
/// 
/// Features:
/// - Swipe horizontally to dismiss
/// - Cross (X) button to dismiss
/// - Floating behavior with rounded corners
/// - Predefined types: success, error, info, warning
/// - Customizable duration and appearance
/// 
/// Usage:
/// ```dart
/// EnhancedSnackBar.showSuccess(context, message: 'Success!');
/// EnhancedSnackBar.showError(context, message: 'Error occurred');
/// EnhancedSnackBar.show(context, message: 'Custom message', backgroundColor: Colors.purple);
/// ```
class EnhancedSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration? duration,
    bool showDismissButton = true,
    bool enableSwipeToDismiss = true,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: _EnhancedSnackBarContent(
          message: message,
          showDismissButton: showDismissButton,
          onDismiss: () => scaffoldMessenger.hideCurrentSnackBar(),
        ),
        backgroundColor: backgroundColor ?? Colors.green,
        duration: duration ?? const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        dismissDirection: enableSwipeToDismiss 
            ? DismissDirection.horizontal 
            : DismissDirection.none,
        action: showDismissButton
            ? SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
              )
            : null,
      ),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration? duration,
    bool showDismissButton = true,
    bool enableSwipeToDismiss = true,
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.red,
      duration: duration,
      showDismissButton: showDismissButton,
      enableSwipeToDismiss: enableSwipeToDismiss,
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration? duration,
    bool showDismissButton = true,
    bool enableSwipeToDismiss = true,
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.green,
      duration: duration,
      showDismissButton: showDismissButton,
      enableSwipeToDismiss: enableSwipeToDismiss,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration? duration,
    bool showDismissButton = true,
    bool enableSwipeToDismiss = true,
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.blue,
      duration: duration,
      showDismissButton: showDismissButton,
      enableSwipeToDismiss: enableSwipeToDismiss,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    Duration? duration,
    bool showDismissButton = true,
    bool enableSwipeToDismiss = true,
  }) {
    show(
      context,
      message: message,
      backgroundColor: Colors.orange,
      duration: duration,
      showDismissButton: showDismissButton,
      enableSwipeToDismiss: enableSwipeToDismiss,
    );
  }
}

class _EnhancedSnackBarContent extends StatelessWidget {
  final String message;
  final bool showDismissButton;
  final VoidCallback onDismiss;

  const _EnhancedSnackBarContent({
    required this.message,
    required this.showDismissButton,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
        if (showDismissButton) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
