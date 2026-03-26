import '../models/flash_card.dart';
import '../models/deck.dart';
import 'timed_difficulty.dart';

class StudyConfig {
  final List<String> deckIds;
  final List<String> deckNames;
  final int cardCount;
  final bool useSRSFiltering;
  final bool startFlipped;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final int? timePerQuestion;
  final bool useAllCardsForAnswers;
  final bool oneAnswerMode;

  const StudyConfig({
    required this.deckIds,
    required this.deckNames,
    required this.cardCount,
    required this.useSRSFiltering,
    required this.startFlipped,
    required this.autoProgress,
    required this.useLivesMode,
    this.customLives,
    required this.useTimedMode,
    this.timedDifficulty,
    this.timePerQuestion,
    required this.useAllCardsForAnswers,
    this.oneAnswerMode = false,
  });

  StudyConfig copyWith({
    List<String>? deckIds,
    List<String>? deckNames,
    int? cardCount,
    bool? useSRSFiltering,
    bool? startFlipped,
    bool? autoProgress,
    bool? useLivesMode,
    int? customLives,
    bool? useTimedMode,
    TimedDifficulty? timedDifficulty,
    int? timePerQuestion,
    bool? useAllCardsForAnswers,
    bool? oneAnswerMode,
  }) {
    return StudyConfig(
      deckIds: deckIds ?? this.deckIds,
      deckNames: deckNames ?? this.deckNames,
      cardCount: cardCount ?? this.cardCount,
      useSRSFiltering: useSRSFiltering ?? this.useSRSFiltering,
      startFlipped: startFlipped ?? this.startFlipped,
      autoProgress: autoProgress ?? this.autoProgress,
      useLivesMode: useLivesMode ?? this.useLivesMode,
      customLives: customLives ?? this.customLives,
      useTimedMode: useTimedMode ?? this.useTimedMode,
      timedDifficulty: timedDifficulty ?? this.timedDifficulty,
      timePerQuestion: timePerQuestion ?? this.timePerQuestion,
      useAllCardsForAnswers: useAllCardsForAnswers ?? this.useAllCardsForAnswers,
      oneAnswerMode: oneAnswerMode ?? this.oneAnswerMode,
    );
  }
}

