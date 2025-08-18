class GameSession {
  int xpGained = 0;
  int correctAnswers = 0;
  int totalAnswers = 0;
  
  static const int XP_PER_CORRECT_ANSWER = 5;
  
  void recordAnswer(bool isCorrect) {
    totalAnswers++;
    if (isCorrect) {
      correctAnswers++;
      xpGained += XP_PER_CORRECT_ANSWER;
    }
  }
  
  double get accuracy => totalAnswers > 0 ? (correctAnswers / totalAnswers) : 0.0;
  int get accuracyPercentage => (accuracy * 100).round();
  
  void reset() {
    xpGained = 0;
    correctAnswers = 0;
    totalAnswers = 0;
  }
}
