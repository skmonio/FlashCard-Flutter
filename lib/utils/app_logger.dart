import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void log(Object? message) {
    if (kDebugMode) {
      print(message);
    }
  }
}
