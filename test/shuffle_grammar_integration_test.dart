import 'package:flutter_test/flutter_test.dart';
import 'package:taal_trek_dutch/views/shuffle_cards_view.dart';

void main() {
  group('Shuffle Cards Grammar Integration', () {
    test('should include grammar exercise mode in enum', () {
      expect(ShuffleMode.values.contains(ShuffleMode.grammarExercise), true);
    });

    test('should have grammar exercise as a valid mode', () {
      expect(ShuffleMode.grammarExercise, isNotNull);
      expect(ShuffleMode.grammarExercise.toString(), contains('grammarExercise'));
    });

    test('should have correct number of shuffle modes', () {
      // Should now have 7 modes: multipleChoice, trueFalse, memoryGame, wordScramble, writing, dutchExercise, grammarExercise
      expect(ShuffleMode.values.length, 7);
    });
  });
}
