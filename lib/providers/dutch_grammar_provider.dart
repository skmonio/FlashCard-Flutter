import 'package:flutter/foundation.dart';
import '../models/dutch_grammar_rule.dart';
import '../data/dutch_grammar_rules.dart';

class DutchGrammarProvider extends ChangeNotifier {
  List<DutchGrammarRule> _allRules = [];
  List<DutchGrammarRule> _filteredRules = [];
  String _searchQuery = '';
  bool _isLoading = true;
  
  // User progress tracking
  Map<String, int> _ruleProgress = {}; // ruleId -> completed exercises count
  Map<String, List<bool>> _exerciseResults = {}; // ruleId -> list of exercise results
  
  // Enhanced history tracking
  Map<String, List<GrammarStudySession>> _studyHistory = {}; // ruleId -> list of study sessions
  Map<String, double> _ruleAccuracy = {}; // ruleId -> overall accuracy percentage

  DutchGrammarProvider() {
    _loadRules();
  }

  Future<void> _loadRules() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _allRules = await DutchGrammarRulesDatabase.allRules;
      _filteredRules = _allRules;
    } catch (e) {
      print('Error loading grammar rules: $e');
      _allRules = [];
      _filteredRules = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Getters
  List<DutchGrammarRule> get allRules => _allRules;
  List<DutchGrammarRule> get filteredRules => _filteredRules;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  // Get rules by level
  List<DutchGrammarRule> getRulesByLevel(LanguageLevel level) {
    return _allRules.where((rule) => rule.level == level).toList();
  }

  // Get rules by type
  List<DutchGrammarRule> getRulesByType(GrammarRuleType type) {
    return _allRules.where((rule) => rule.type == type).toList();
  }

  // Get a specific rule by ID
  DutchGrammarRule? getRuleById(String id) {
    try {
      return _allRules.firstWhere((rule) => rule.id == id);
    } catch (e) {
      return null;
    }
  }

  // Filter rules
  void filterRules({
    String? searchQuery,
  }) {
    _searchQuery = searchQuery ?? '';

    _filteredRules = _allRules.where((rule) {
      bool matchesSearch = _searchQuery.isEmpty ||
          rule.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          rule.explanation.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesSearch;
    }).toList();

    notifyListeners();
  }

  // Clear filters
  void clearFilters() {
    _searchQuery = '';
    _filteredRules = _allRules;
    notifyListeners();
  }

  // Progress tracking
  int getRuleProgress(String ruleId) {
    return _ruleProgress[ruleId] ?? 0;
  }

  double getRuleProgressPercentage(String ruleId) {
    final rule = getRuleById(ruleId);
    if (rule == null) return 0.0;
    
    final completed = getRuleProgress(ruleId);
    final total = rule.exercises.length;
    
    return total > 0 ? completed / total : 0.0;
  }

  List<bool> getExerciseResults(String ruleId) {
    return _exerciseResults[ruleId] ?? [];
  }

  // Record exercise result
  void recordExerciseResult(String ruleId, int exerciseIndex, bool isCorrect) {
    if (!_exerciseResults.containsKey(ruleId)) {
      _exerciseResults[ruleId] = List.filled(
        getRuleById(ruleId)?.exercises.length ?? 0,
        false,
      );
    }

    final results = _exerciseResults[ruleId]!;
    if (exerciseIndex < results.length) {
      results[exerciseIndex] = isCorrect;
      
      // Update progress
      final completedCount = results.where((result) => result).length;
      _ruleProgress[ruleId] = completedCount;
    }

    notifyListeners();
  }

  // Record a complete study session
  void recordStudySession(String ruleId, GrammarStudySession session) {
    if (!_studyHistory.containsKey(ruleId)) {
      _studyHistory[ruleId] = [];
    }
    
    _studyHistory[ruleId]!.add(session);
    
    // Update overall accuracy for this rule
    _updateRuleAccuracy(ruleId);
    
    notifyListeners();
  }

  // Get study history for a rule
  List<GrammarStudySession> getStudyHistory(String ruleId) {
    return _studyHistory[ruleId] ?? [];
  }

  // Get overall accuracy for a rule
  double getRuleAccuracy(String ruleId) {
    return _ruleAccuracy[ruleId] ?? 0.0;
  }

  // Get recent study sessions (last 5)
  List<GrammarStudySession> getRecentStudyHistory(String ruleId) {
    final history = getStudyHistory(ruleId);
    history.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
    return history.take(5).toList();
  }

  // Get study statistics for a rule
  Map<String, dynamic> getRuleStudyStatistics(String ruleId) {
    final history = getStudyHistory(ruleId);
    if (history.isEmpty) {
      return {
        'totalSessions': 0,
        'totalQuestions': 0,
        'totalCorrect': 0,
        'overallAccuracy': 0.0,
        'averageTimePerSession': 0,
        'bestAccuracy': 0.0,
        'lastStudied': null,
      };
    }

    final totalSessions = history.length;
    final totalQuestions = history.fold(0, (sum, session) => sum + session.totalQuestions);
    final totalCorrect = history.fold(0, (sum, session) => sum + session.correctAnswers);
    final overallAccuracy = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;
    final averageTimePerSession = history.fold(0, (sum, session) => sum + session.timeSpentSeconds) / totalSessions;
    final bestAccuracy = history.map((session) => session.accuracy).reduce((a, b) => a > b ? a : b);
    final lastStudied = history.map((session) => session.date).reduce((a, b) => a.isAfter(b) ? a : b);

    return {
      'totalSessions': totalSessions,
      'totalQuestions': totalQuestions,
      'totalCorrect': totalCorrect,
      'overallAccuracy': overallAccuracy,
      'averageTimePerSession': averageTimePerSession,
      'bestAccuracy': bestAccuracy,
      'lastStudied': lastStudied,
    };
  }

  // Update rule accuracy based on all study sessions
  void _updateRuleAccuracy(String ruleId) {
    final history = getStudyHistory(ruleId);
    if (history.isEmpty) {
      _ruleAccuracy[ruleId] = 0.0;
      return;
    }

    final totalQuestions = history.fold(0, (sum, session) => sum + session.totalQuestions);
    final totalCorrect = history.fold(0, (sum, session) => sum + session.correctAnswers);
    
    _ruleAccuracy[ruleId] = totalQuestions > 0 ? totalCorrect / totalQuestions : 0.0;
  }

  // Get random exercises for practice
  List<GrammarExercise> getRandomExercises(int count) {
    final allExercises = <GrammarExercise>[];
    
    for (final rule in _allRules) {
      allExercises.addAll(rule.exercises);
    }
    
    allExercises.shuffle();
    return allExercises.take(count).toList();
  }

  // Get exercises by type
  List<GrammarExercise> getExercisesByType(ExerciseType type, {int? limit}) {
    final exercises = <GrammarExercise>[];
    
    for (final rule in _allRules) {
      final typeExercises = rule.exercises.where((ex) => ex.exerciseType == type);
      exercises.addAll(typeExercises);
    }
    
    exercises.shuffle();
    return limit != null ? exercises.take(limit).toList() : exercises;
  }

  // Get exercises by level
  List<GrammarExercise> getExercisesByLevel(LanguageLevel level, {int? limit}) {
    final exercises = <GrammarExercise>[];
    
    for (final rule in _allRules.where((r) => r.level == level)) {
      exercises.addAll(rule.exercises);
    }
    
    exercises.shuffle();
    return limit != null ? exercises.take(limit).toList() : exercises;
  }

  // Get mixed exercises for comprehensive practice
  List<GrammarExercise> getMixedExercises({
    int count = 10,
    List<LanguageLevel>? levels,
    List<ExerciseType>? types,
  }) {
    final exercises = <GrammarExercise>[];
    
    for (final rule in _allRules) {
      if (levels == null || levels.contains(rule.level)) {
        for (final exercise in rule.exercises) {
          if (types == null || types.contains(exercise.exerciseType)) {
            exercises.add(exercise);
          }
        }
      }
    }
    
    exercises.shuffle();
    return exercises.take(count).toList();
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    final totalRules = _allRules.length;
    final totalExercises = _allRules.fold(0, (sum, rule) => sum + rule.exercises.length);
    
    final completedRules = _ruleProgress.values.where((count) => count > 0).length;
    final totalCompleted = _ruleProgress.values.fold(0, (sum, count) => sum + count);
    
    final correctAnswers = _exerciseResults.values
        .expand((results) => results)
        .where((result) => result)
        .length;
    
    final totalAttempts = _exerciseResults.values
        .expand((results) => results)
        .where((result) => result != null)
        .length;
    
    final accuracy = totalAttempts > 0 ? correctAnswers / totalAttempts : 0.0;
    
    return {
      'totalRules': totalRules,
      'totalExercises': totalExercises,
      'completedRules': completedRules,
      'totalCompleted': totalCompleted,
      'correctAnswers': correctAnswers,
      'totalAttempts': totalAttempts,
      'accuracy': accuracy,
    };
  }

  // Export/Import functionality
  Map<String, dynamic> exportData() {
    return {
      'ruleProgress': _ruleProgress,
      'exerciseResults': _exerciseResults.map(
        (key, value) => MapEntry(key, value.map((e) => e).toList()),
      ),
      'studyHistory': _studyHistory.map(
        (key, value) => MapEntry(key, value.map((session) => session.toJson()).toList()),
      ),
      'ruleAccuracy': _ruleAccuracy,
    };
  }

  void importData(Map<String, dynamic> data) {
    if (data.containsKey('ruleProgress')) {
      _ruleProgress = Map<String, int>.from(data['ruleProgress']);
    }
    
    if (data.containsKey('exerciseResults')) {
      _exerciseResults = (data['exerciseResults'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<bool>.from(value)),
      );
    }

    if (data.containsKey('studyHistory')) {
      _studyHistory = (data['studyHistory'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key, 
          (value as List).map((sessionJson) => GrammarStudySession.fromJson(sessionJson)).toList(),
        ),
      );
    }

    if (data.containsKey('ruleAccuracy')) {
      _ruleAccuracy = (data['ruleAccuracy'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    }
    
    notifyListeners();
  }

  // Reset progress
  void resetProgress() {
    _ruleProgress.clear();
    _exerciseResults.clear();
    _studyHistory.clear();
    _ruleAccuracy.clear();
    notifyListeners();
  }

  // Get recommended rules based on progress
  List<DutchGrammarRule> getRecommendedRules({int count = 5}) {
    final recommendations = <DutchGrammarRule>[];
    
    // First, recommend rules with no progress
    final noProgressRules = _allRules.where((rule) => 
      getRuleProgress(rule.id) == 0
    ).toList();
    
    if (noProgressRules.isNotEmpty) {
      noProgressRules.shuffle();
      recommendations.addAll(noProgressRules.take(count));
    }
    
    // If we need more, add rules with low progress
    if (recommendations.length < count) {
      final lowProgressRules = _allRules.where((rule) => 
        getRuleProgress(rule.id) > 0 && 
        getRuleProgressPercentage(rule.id) < 0.5 &&
        !recommendations.contains(rule)
      ).toList();
      
      lowProgressRules.shuffle();
      recommendations.addAll(lowProgressRules.take(count - recommendations.length));
    }
    
    return recommendations;
  }
}
