import 'package:shared_preferences/shared_preferences.dart';

class DataCleanupService {
  static const String _cleanupPerformedKey = 'exercises_phrases_cleanup_version_1';

  static Future<void> performCleanupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyCleaned = prefs.getBool(_cleanupPerformedKey) ?? false;

    if (!alreadyCleaned) {
      print('🧹 DataCleanupService: Starting one-time cleanup of Exercises and Phrases data...');
      
      // Remove Exercises data
      if (prefs.containsKey('dutch_word_exercises')) {
        await prefs.remove('dutch_word_exercises');
        print('🧹 DataCleanupService: Removed old exercises data');
      }
      
      // Remove Phrases data
      if (prefs.containsKey('phrases')) {
        await prefs.remove('phrases');
        print('🧹 DataCleanupService: Removed old phrases data');
      }
      
      // Mark cleanup as performed
      await prefs.setBool(_cleanupPerformedKey, true);
      print('🧹 DataCleanupService: Cleanup complete');
    } else {
      print('🧹 DataCleanupService: Cleanup already performed previously');
    }
  }
}
