import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flashcard_app/providers/dutch_grammar_provider.dart';
import 'package:flashcard_app/models/dutch_grammar_rule.dart';

void main() {
  group('Dutch Grammar History Tracking', () {
    late DutchGrammarProvider provider;

    setUp(() {
      provider = DutchGrammarProvider();
    });

    test('should record study session correctly', () {
      final ruleId = 'test_rule';
      final session = GrammarStudySession(
        date: DateTime.now(),
        totalQuestions: 10,
        correctAnswers: 8,
        accuracy: 0.8,
        timeSpentSeconds: 120,
        questionResults: [1, 1, 0, 1, 1, 1, 0, 1, 1, 1],
      );

      provider.recordStudySession(ruleId, session);

      final history = provider.getStudyHistory(ruleId);
      expect(history.length, 1);
      expect(history.first.totalQuestions, 10);
      expect(history.first.correctAnswers, 8);
      expect(history.first.accuracy, 0.8);
    });

    test('should calculate overall accuracy correctly', () {
      final ruleId = 'test_rule';
      
      // First session: 8/10 correct (80%)
      final session1 = GrammarStudySession(
        date: DateTime.now(),
        totalQuestions: 10,
        correctAnswers: 8,
        accuracy: 0.8,
        timeSpentSeconds: 120,
        questionResults: [1, 1, 0, 1, 1, 1, 0, 1, 1, 1],
      );

      // Second session: 9/10 correct (90%)
      final session2 = GrammarStudySession(
        date: DateTime.now(),
        totalQuestions: 10,
        correctAnswers: 9,
        accuracy: 0.9,
        timeSpentSeconds: 100,
        questionResults: [1, 1, 1, 1, 1, 1, 0, 1, 1, 1],
      );

      provider.recordStudySession(ruleId, session1);
      provider.recordStudySession(ruleId, session2);

      final accuracy = provider.getRuleAccuracy(ruleId);
      // Overall: 17 correct out of 20 total = 85%
      expect(accuracy, 0.85);
    });

    test('should get study statistics correctly', () {
      final ruleId = 'test_rule';
      final session = GrammarStudySession(
        date: DateTime.now(),
        totalQuestions: 10,
        correctAnswers: 8,
        accuracy: 0.8,
        timeSpentSeconds: 120,
        questionResults: [1, 1, 0, 1, 1, 1, 0, 1, 1, 1],
      );

      provider.recordStudySession(ruleId, session);

      final statistics = provider.getRuleStudyStatistics(ruleId);
      expect(statistics['totalSessions'], 1);
      expect(statistics['totalQuestions'], 10);
      expect(statistics['totalCorrect'], 8);
      expect(statistics['overallAccuracy'], 0.8);
      expect(statistics['averageTimePerSession'], 120);
      expect(statistics['bestAccuracy'], 0.8);
      expect(statistics['lastStudied'], isNotNull);
    });

    test('should get recent study history correctly', () {
      final ruleId = 'test_rule';
      
      // Create 7 sessions
      for (int i = 0; i < 7; i++) {
        final session = GrammarStudySession(
          date: DateTime.now().subtract(Duration(days: i)),
          totalQuestions: 10,
          correctAnswers: 8,
          accuracy: 0.8,
          timeSpentSeconds: 120,
          questionResults: List.filled(10, 1),
        );
        provider.recordStudySession(ruleId, session);
      }

      final recentHistory = provider.getRecentStudyHistory(ruleId);
      // Should only return the 5 most recent sessions
      expect(recentHistory.length, 5);
      
      // Should be sorted by date (most recent first)
      for (int i = 0; i < recentHistory.length - 1; i++) {
        expect(recentHistory[i].date.isAfter(recentHistory[i + 1].date), true);
      }
    });

    test('should handle empty history correctly', () {
      final ruleId = 'test_rule';
      
      final history = provider.getStudyHistory(ruleId);
      expect(history.length, 0);
      
      final accuracy = provider.getRuleAccuracy(ruleId);
      expect(accuracy, 0.0);
      
      final statistics = provider.getRuleStudyStatistics(ruleId);
      expect(statistics['totalSessions'], 0);
      expect(statistics['totalQuestions'], 0);
      expect(statistics['totalCorrect'], 0);
      expect(statistics['overallAccuracy'], 0.0);
      expect(statistics['lastStudied'], isNull);
    });
  });
}
