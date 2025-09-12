import 'package:flutter/material.dart';

class GlobalNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static BuildContext? get currentContext => navigatorKey.currentContext;
  
  static void showSnackBar(String message, {Color? backgroundColor}) {
    final context = currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
  
  static void showAlertDialog({
    required String title,
    required String content,
    List<Widget>? actions,
  }) {
    final context = currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: actions ?? [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
