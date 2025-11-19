import 'package:flutter/material.dart';

import '../components/unified_end_screen.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';

class GameEndResult {
  final String title;
  final List<FlashCard> studiedWords;
  final Map<String, int> xpGainedPerWord;
  final Map<String, LearningMastery> wordMastery;
  final Map<String, int>? initialHPPerWord;
  final int? correctAnswers;
  final int? totalQuestions;
  final bool showSwipeToReview;
  final VoidCallback? onStudyAgain;
  final VoidCallback? onShuffle;
  final VoidCallback? onDone;

  const GameEndResult({
    required this.title,
    required this.studiedWords,
    required this.xpGainedPerWord,
    required this.wordMastery,
    this.initialHPPerWord,
    this.correctAnswers,
    this.totalQuestions,
    this.showSwipeToReview = false,
    this.onStudyAgain,
    this.onShuffle,
    this.onDone,
  });
}

class GameEndScreen {
  static Future<T?> show<T>(BuildContext context, GameEndResult result) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (context) => _buildWidget(result),
      ),
    );
  }

  static Widget view(GameEndResult result) => _buildWidget(result);

  static UnifiedEndScreen _buildWidget(GameEndResult result) {
    return UnifiedEndScreen(
      title: result.title,
      studiedWords: result.studiedWords,
      xpGainedPerWord: result.xpGainedPerWord,
      wordMastery: result.wordMastery,
      initialHPPerWord: result.initialHPPerWord,
      correctAnswers: result.correctAnswers,
      totalQuestions: result.totalQuestions,
      showSwipeToReview: result.showSwipeToReview,
      onStudyAgain: result.onStudyAgain,
      onShuffle: result.onShuffle,
      onDone: result.onDone,
    );
  }
}

