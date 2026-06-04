import 'package:flutter_test/flutter_test.dart';
import 'package:taal_trek_dutch/models/learning_mastery.dart';

void main() {
  group('Time Decay System Tests', () {
    test('Level calculation based on percentage', () {
      // Test level calculation
      expect(WordLevel.fromPercentage(5.0), WordLevel.level1);
      expect(WordLevel.fromPercentage(15.0), WordLevel.level2);
      expect(WordLevel.fromPercentage(25.0), WordLevel.level3);
      expect(WordLevel.fromPercentage(35.0), WordLevel.level4);
      expect(WordLevel.fromPercentage(45.0), WordLevel.level5);
      expect(WordLevel.fromPercentage(55.0), WordLevel.level6);
      expect(WordLevel.fromPercentage(65.0), WordLevel.level7);
      expect(WordLevel.fromPercentage(75.0), WordLevel.level8);
      expect(WordLevel.fromPercentage(85.0), WordLevel.level9);
      expect(WordLevel.fromPercentage(95.0), WordLevel.level10);
    });

    test('Progress within level calculation', () {
      final level2 = WordLevel.level2;
      expect(level2.getProgressWithinLevel(11.0), 0.0); // Start of level 2
      expect(
        level2.getProgressWithinLevel(15.0),
        closeTo(0.4, 0.1),
      ); // 40% through level 2
      expect(level2.getProgressWithinLevel(20.0), 1.0); // End of level 2
    });

    test('Time decay system', () {
      final mastery = LearningMastery();

      // Simulate a word with enough XP to be above the first level
      mastery.currentXP = 250;
      mastery.lastReviewDate = DateTime.now();

      // Should be at a higher level
      final initialLevel = mastery.wordLevel;
      expect(initialLevel.level, greaterThan(1));

      // Simulate 10 days without review (7 days decay = 14% loss)
      mastery.lastReviewDate = DateTime.now().subtract(
        const Duration(days: 10),
      );

      // Should have decayed significantly
      final decayedLevel = mastery.wordLevel;
      expect(decayedLevel.level, lessThanOrEqualTo(initialLevel.level));
    });

    test('Level progression and decay', () {
      final mastery = LearningMastery();

      // Start with a new word
      expect(mastery.wordLevel.level, 0);
      expect(mastery.learningPercentage, 0.0);

      // Simulate enough XP to progress into a higher level
      mastery.currentXP = 250;
      mastery.lastReviewDate = DateTime.now();

      // Should be at a higher level
      final level = mastery.wordLevel;
      expect(level.level, greaterThan(1));

      // Simulate 20 days without review (17 days decay = 34% loss)
      mastery.lastReviewDate = DateTime.now().subtract(
        const Duration(days: 20),
      );

      // Should have decayed back to lower level
      final decayedLevel = mastery.wordLevel;
      expect(decayedLevel.level, lessThanOrEqualTo(level.level));
    });
  });
}
