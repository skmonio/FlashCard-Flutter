import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../views/study_type_selection_view.dart';

class _GuideContent {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> steps;

  const _GuideContent(this.title, this.icon, this.color, this.steps);
}

class GameGuideDialog {
  static const _prefix = 'guide_seen_';

  static final Map<GameMode, _GuideContent> _guides = {
    GameMode.study:
        _GuideContent('Study Your Cards', Icons.school, Colors.teal, [
          'A Dutch word appears on the front of the card.',
          'Double-tap the card to flip it and reveal the translation.',
          'Swipe right if you knew it, or swipe left if you did not.',
          'Use the Back and Next buttons at the bottom to navigate.',
        ]),
    GameMode.test: _GuideContent('Test Your Cards', Icons.quiz, Colors.orange, [
      'A Dutch word is shown with four English meanings.',
      'Tap A, B, C, or D to select your answer.',
      'Correct answers turn green and wrong answers turn red.',
      'Tap Next to move to the next question.',
    ]),
    GameMode.trueFalse: _GuideContent(
      'True or False',
      Icons.help_outline,
      const Color(0xFFFF6B4D),
      [
        'A Dutch word and a translation are shown together.',
        'Tap TRUE if the pair is correct.',
        'Tap FALSE if the pair is wrong.',
        'Your result appears immediately.',
      ],
    ),
    GameMode.wordScramble:
        _GuideContent('Jumble Your Cards', Icons.abc, Colors.green, [
          'An English definition is shown at the top.',
          'Scrambled letter tiles spell out the Dutch word.',
          'Tap letters one by one to build the correct word.',
          'Tap a placed letter to return it to the pool.',
          'Tap CHECK when done, or SKIP to move on.',
        ]),
    GameMode.connectCards:
        _GuideContent('Connect Your Cards', Icons.grid_on, Colors.purple, [
          'A target Dutch word is shown above the grid.',
          'Drag across adjacent letter tiles to spell the word.',
          'Release after the final letter to submit the path.',
          'Complete all words to finish the round.',
        ]),
    GameMode.write: _GuideContent('Write Your Card', Icons.edit, Colors.blue, [
      'An English translation or hint is shown.',
      'Type the Dutch word in the text field.',
      'Submit your answer to see if you were right.',
    ]),
    GameMode.game:
        _GuideContent('Remember Your Cards', Icons.psychology, Colors.orange, [
          'Cards are placed face-down in a grid.',
          'Tap any card to reveal it.',
          'Find matching Dutch word and English translation pairs.',
          'Match all pairs to complete the game.',
        ]),
    GameMode.sentenceBuilding:
        _GuideContent('Sentence Your Cards', Icons.reorder, Colors.blueGrey, [
          'A scrambled sentence is shown word by word.',
          'Tap words in the correct order to build the sentence.',
          'Tap a placed word to remove it and try again.',
          'Submit when all words are in place.',
        ]),
    GameMode.deHet:
        _GuideContent('De of Het', Icons.article, const Color(0xFF1565C0), [
          'A Dutch noun appears on screen.',
          'Tap DE or HET for the correct article.',
          'Only cards with an article set will appear in this mode.',
        ]),
    GameMode.soManyCards: _GuideContent(
      'So Many Cards',
      Icons.library_add,
      const Color(0xFFFF9800),
      [
        'A Dutch noun is shown.',
        'Choose the correct plural form from the options.',
        'Common patterns include -en, -s, -eren, and -ren.',
      ],
    ),
    GameMode.timeYourCards:
        _GuideContent('Time Your Cards', Icons.timer, const Color(0xFFE91E63), [
          'A Dutch verb appears on screen.',
          'Select the correct tense: present, past, or perfect.',
          'A timer counts down, so answer before time runs out.',
        ]),
    GameMode.pickYourCard:
        _GuideContent('Pick Your Card', Icons.tune, Colors.indigo, [
          'Spinning wheels show letter combinations.',
          'Spin each wheel to line up the correct Dutch word.',
          'Tap CHECK when the wheels show the right answer.',
        ]),
    GameMode.popYourCard:
        _GuideContent('Pop Your Card', Icons.bubble_chart, Colors.cyan, [
          'Word bubbles float around the screen.',
          'An English word is shown as your prompt.',
          'Find and tap the correct Dutch bubble.',
          'Avoid tapping wrong bubbles.',
        ]),
  };

  static Future<bool> hasSeenGuide(GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix${mode.name}') ?? false;
  }

  static Future<void> markSeen(GameMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix${mode.name}', true);
  }

  static Future<bool> showIfFirstTime(
    BuildContext context,
    GameMode mode,
  ) async {
    if (await hasSeenGuide(mode)) return false;
    if (!context.mounted) return false;

    await show(context, mode);
    await markSeen(mode);
    return true;
  }

  static Future<void> show(BuildContext context, GameMode mode) async {
    final guide = _guides[mode];
    if (guide == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GameGuideSheet(guide: guide),
    );
  }
}

class _GameGuideSheet extends StatelessWidget {
  final _GuideContent guide;

  const _GameGuideSheet({required this.guide});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: guide.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(guide.icon, color: guide.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to Play',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        guide.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...guide.steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: guide.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: guide.color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(step, style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: guide.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
