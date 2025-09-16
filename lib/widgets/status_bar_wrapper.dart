import 'package:flutter/material.dart';
import '../utils/status_bar_utils.dart';

/// A wrapper widget that ensures the status bar is correctly configured
/// based on the current theme. Use this in views where status bar issues occur.
class StatusBarWrapper extends StatelessWidget {
  final Widget child;
  final bool forceLightStatusBar;
  final bool forceDarkStatusBar;

  const StatusBarWrapper({
    super.key,
    required this.child,
    this.forceLightStatusBar = false,
    this.forceDarkStatusBar = false,
  });

  @override
  Widget build(BuildContext context) {
    // Update status bar based on theme or forced settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (forceLightStatusBar) {
        StatusBarUtils.setLightStatusBar();
      } else if (forceDarkStatusBar) {
        StatusBarUtils.setDarkStatusBar();
      } else {
        StatusBarUtils.updateStatusBar(context);
      }
    });

    return child;
  }
}
