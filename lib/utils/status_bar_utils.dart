import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatusBarUtils {
  /// Updates the status bar appearance based on the current theme
  static void updateStatusBar(BuildContext context, {bool? isDark}) {
    final brightness = Theme.of(context).brightness;
    final shouldUseDark = isDark ?? (brightness == Brightness.dark);
    
    SystemChrome.setSystemUIOverlayStyle(
      shouldUseDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark, // For iOS
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light, // For iOS
            ),
    );
  }
  
  /// Updates status bar for light theme (black text/icons)
  static void setLightStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light, // For iOS
      ),
    );
  }
  
  /// Updates status bar for dark theme (white text/icons)
  static void setDarkStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // For iOS
      ),
    );
  }
}
