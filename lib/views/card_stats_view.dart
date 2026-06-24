import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/flash_card.dart';
import '../providers/flashcard_provider.dart';
import '../services/xp_service.dart';
import '../components/hp_bar.dart';
import '../components/main_header.dart';
import '../utils/card_color_utils.dart';

class CardStatsView extends StatefulWidget {
  final FlashCard card;

  const CardStatsView({
    super.key,
    required this.card,
  });

  @override
  State<CardStatsView> createState() => _CardStatsViewState();
}

class _CardStatsViewState extends State<CardStatsView> {
  @override
  Widget build(BuildContext context) {
    // Get the fresh card data from the provider
    final provider = context.read<FlashcardProvider>();
    final freshCard = provider.getCard(widget.card.id) ?? widget.card;
    final xpService = XpService();
    final wordLevel = freshCard.learningMastery.rpgWordLevel;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: freshCard.word,
            leftAction: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => Navigator.of(context).pop(),
            ),
            rightAction: IconButton(
              icon: Icon(
                Icons.home,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      freshCard.definition,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Decks: ${CardColorUtils.getDeckNames(freshCard, provider)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (freshCard.plural.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Plural: ${freshCard.plural}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Learning Progress Section
            _buildSection(
              title: 'Learning Progress',
              icon: Icons.trending_up,
              children: [
                _buildStatRow('Learning Percentage', '${freshCard.learningPercentage ?? 0}%'),
                _buildStatRow('Card Level', '${xpService.getLevelIcon(wordLevel)} Level ${wordLevel.level} (${wordLevel.title})'),
                _buildStatRow('Current XP', '${freshCard.learningMastery.currentXPWithDecay}'),
                if (freshCard.learningMastery.xpNeededForNextLevel > 0)
                  _buildStatRow('XP to Next Level', '${freshCard.learningMastery.xpNeededForNextLevel}'),
                _buildStatRow('Next Review', _getNextReviewText(freshCard)),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Study Statistics Section
            _buildSection(
              title: 'Study Statistics',
              icon: Icons.analytics,
              children: [
                _buildStatRow('Times Shown', '${freshCard.timesShown}'),
                _buildStatRow('Times Correct', '${freshCard.timesCorrect}'),
                _buildStatRow('Times Incorrect', '${freshCard.timesShown - freshCard.timesCorrect}'),
                _buildStatRow('Success Rate', _getSuccessRate(freshCard)),
                _buildStatRow('Consecutive Correct', '${freshCard.consecutiveCorrect}'),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Health Points Section
            _buildSection(
              title: 'Health Points',
              icon: Icons.favorite,
              children: [
                Row(
                  children: [
                    Text(
                      'Current HP: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${freshCard.currentHP}/${freshCard.maxHP}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HPBar(
                  currentHP: freshCard.currentHP,
                  maxHP: freshCard.maxHP,
                  showText: true,
                  showStatus: true,
                ),
                const SizedBox(height: 12),
                _buildHpHealingInfo(freshCard),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Game Usage Section
            _buildSection(
              title: 'Game Usage',
              icon: Icons.games,
              children: [
                _buildGameUsageStats(freshCard),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Dates Section
            _buildSection(
              title: 'Card Information',
              icon: Icons.info,
              children: [
                _buildStatRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(freshCard.dateCreated)),
                _buildStatRow('Last Modified', DateFormat('MMM dd, yyyy HH:mm').format(freshCard.lastModified)),
                _buildStatRow('Last Studied', _getLastStudiedText(freshCard)),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Performance Insights
            _buildSection(
              title: 'Performance Insights',
              icon: Icons.lightbulb,
              children: [
                _buildPerformanceInsights(freshCard),
              ],
            ),
          ],
        ),
      ),
    ),
  ],
),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGameUsageStats(FlashCard card) {
    final mastery = card.learningMastery;
    
    // Count usage by exercise type from exerciseHistory
    final Map<String, int> gameUsage = {};
    final Map<String, int> gameCorrect = {};
    
    for (final entry in mastery.exerciseHistory) {
      final exerciseType = entry['exerciseType'] as String;
      final xpGained = entry['xpGained'] as int;
      
      gameUsage[exerciseType] = (gameUsage[exerciseType] ?? 0) + 1;
      if (xpGained > 0) {
        gameCorrect[exerciseType] = (gameCorrect[exerciseType] ?? 0) + 1;
      }
    }
    
    // Map exercise types to display names
    final Map<String, String> gameDisplayNames = {
      'study': 'Study Your Cards',
      'test': 'Test Your Cards',
      'true_false': 'True or False',
      'memory': 'Remember Your Cards',
      'word_scramble': 'Jumble Your Cards',
      'pickYourCard': 'Pick Your Cards',
      'writing': 'Write Your Cards',
      'multiple_choice': 'Test Your Cards',
      'popYourCard': 'Pop Your Cards',
      'timed_multiple_choice': 'Timed Test Your Cards',
      'timed_true_false': 'Timed True or False',
      'timed_word_scramble': 'Timed Jumble Your Cards',
      'dutch_word_exercise_detail': 'Exercise',
      'sentence': 'Sentence Your Cards',
      'de_het': 'De of Het',
    };
    
    // Get unique game names in order of preference
    final List<String> gameNames = gameDisplayNames.values.toSet().toList();
    gameNames.sort();
    
    // Generate list of game usage widgets
    final List<Widget> gameUsageWidgets = [];
    
    for (final gameName in gameNames) {
      final exerciseTypes = gameDisplayNames.entries
          .where((entry) => entry.value == gameName)
          .map((entry) => entry.key)
          .toList();
      
      final totalAttempts = exerciseTypes.fold<int>(0, (sum, type) => sum + (gameUsage[type] ?? 0));
      final totalCorrect = exerciseTypes.fold<int>(0, (sum, type) => sum + (gameCorrect[type] ?? 0));
      
      if (totalAttempts > 0) {
        gameUsageWidgets.add(_buildStatRow(gameName, '$totalAttempts times ($totalCorrect correct)'));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show usage for each game type that has been played
        ...gameUsageWidgets,
        
        // Show message if no game usage data
        if (gameUsage.isEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This card hasn\'t been used in any games yet. Play some games to see usage statistics here!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: ${mastery.totalAttempts} attempts, ${mastery.totalCorrect} correct (${(mastery.accuracy * 100).toStringAsFixed(1)}% accuracy)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPerformanceInsights(FlashCard card) {
    final insights = <Widget>[];
    
    // Success rate insight
    final successRate = card.timesShown > 0 ? (card.timesCorrect / card.timesShown * 100) : 0;
    if (successRate >= 80) {
      insights.add(_buildInsightItem(
        Icons.check_circle,
        Colors.green,
        'Excellent performance! You have a ${successRate.toStringAsFixed(1)}% success rate.',
      ));
    } else if (successRate >= 60) {
      insights.add(_buildInsightItem(
        Icons.info,
        Colors.orange,
        'Good progress! You have a ${successRate.toStringAsFixed(1)}% success rate. Keep practicing!',
      ));
    } else if (card.timesShown > 0) {
      insights.add(_buildInsightItem(
        Icons.warning,
        Colors.red,
        'Consider reviewing this word more. Current success rate: ${successRate.toStringAsFixed(1)}%',
      ));
    }
    
    // Streak insight
    if (card.consecutiveCorrect >= 5) {
      insights.add(_buildInsightItem(
        Icons.local_fire_department,
        Colors.orange,
        'Great streak! You\'ve answered correctly ${card.consecutiveCorrect} times in a row.',
      ));
    }
    
    // Study frequency insight
    if (card.timesShown == 0) {
      insights.add(_buildInsightItem(
        Icons.school,
        Colors.blue,
        'This card hasn\'t been studied yet. Start practicing to build your knowledge!',
      ));
    } else if (card.timesShown < 3) {
      insights.add(_buildInsightItem(
        Icons.trending_up,
        Colors.blue,
        'New card! You\'ve studied this ${card.timesShown} time${card.timesShown == 1 ? '' : 's'}. Keep practicing!',
      ));
    }
    
    if (insights.isEmpty) {
      insights.add(_buildInsightItem(
        Icons.emoji_events,
        Colors.green,
        'Keep up the great work! This card is performing well.',
      ));
    }
    
    return Column(children: insights);
  }

  Widget _buildInsightItem(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextReviewText(FlashCard card) {
    if (card.nextReviewDate == null) {
      return 'Due now';
    }
    
    final now = DateTime.now();
    final nextReview = card.nextReviewDate!;
    
    if (nextReview.isBefore(now)) {
      return 'Due now';
    }
    
    final difference = nextReview.difference(now);
    
    if (difference.inDays > 0) {
      return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'In ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'In ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'Due now';
    }
  }

  String _getSuccessRate(FlashCard card) {
    if (card.timesShown == 0) return '0%';
    final rate = (card.timesCorrect / card.timesShown * 100);
    return '${rate.toStringAsFixed(1)}%';
  }

  String _getLastStudiedText(FlashCard card) {
    // This would ideally come from a study history tracking service
    // For now, we'll use the last modified date as a proxy
    if (card.timesShown == 0) return 'Never studied';
    
    final now = DateTime.now();
    final lastModified = card.lastModified;
    final difference = now.difference(lastModified);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildHpHealingInfo(FlashCard card) {
    final minutesUntilHeal = card.learningMastery.minutesUntilNextHPHeal;

    if (minutesUntilHeal == null) {
      if (card.currentHP >= card.maxHP) {
        return _buildInfoChip(
          icon: Icons.check_circle,
          color: Colors.green,
          label: 'Full health',
          message: 'This word is fully rested and ready to study again.',
        );
      }

      return _buildInfoChip(
        icon: Icons.favorite,
        color: Colors.blue,
        label: 'Recovering',
        message: 'HP is regenerating. Mix in other cards while this one rests.',
      );
    }

    final clampedMinutes = minutesUntilHeal.clamp(0, 60 * 24);
    final hours = clampedMinutes ~/ 60;
    final minutes = clampedMinutes % 60;

    String countdownText;
    if (clampedMinutes == 0) {
      countdownText = 'HP should refresh any moment. Refresh this page to see the latest points.';
    } else if (hours > 0) {
      countdownText = 'Next HP in $hours hour${hours == 1 ? '' : 's'}'
          '${minutes > 0 ? ' $minutes min' : ''}.';
    } else {
      countdownText = 'Next HP in $minutes minute${minutes == 1 ? '' : 's'}.';
    }

    return _buildInfoChip(
      icon: Icons.timer,
      color: Colors.orange,
      label: 'Healing in progress',
      message: countdownText,
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Color color,
    required String label,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
