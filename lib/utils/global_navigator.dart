import 'package:flutter/material.dart';
import 'enhanced_snackbar.dart';

class GlobalNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static BuildContext? get currentContext => navigatorKey.currentContext;
  
  static void showSnackBar(String message, {Color? backgroundColor}) {
    final context = currentContext;
    if (context != null) {
      EnhancedSnackBar.show(
        context,
        message: message,
        backgroundColor: backgroundColor,
      );
    }
  }
  
  static void showErrorSnackBar(String message) {
    final context = currentContext;
    if (context != null) {
      EnhancedSnackBar.showError(context, message: message);
    }
  }
  
  static void showSuccessSnackBar(String message) {
    final context = currentContext;
    if (context != null) {
      EnhancedSnackBar.showSuccess(context, message: message);
    }
  }
  
  static void showInfoSnackBar(String message) {
    final context = currentContext;
    if (context != null) {
      EnhancedSnackBar.showInfo(context, message: message);
    }
  }
  
  static void showWarningSnackBar(String message) {
    final context = currentContext;
    if (context != null) {
      EnhancedSnackBar.showWarning(context, message: message);
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
