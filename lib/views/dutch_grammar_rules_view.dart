import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dutch_grammar_provider.dart';
import '../models/dutch_grammar_rule.dart';
import '../components/unified_header.dart';
import 'dutch_grammar_rule_detail_view.dart';
import 'dutch_grammar_exercise_view.dart';

class DutchGrammarRulesView extends StatefulWidget {
  const DutchGrammarRulesView({super.key});

  @override
  State<DutchGrammarRulesView> createState() => _DutchGrammarRulesViewState();
}

class _DutchGrammarRulesViewState extends State<DutchGrammarRulesView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DutchGrammarProvider>().clearFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: 'Grammar Rules',
            onBack: () => Navigator.of(context).pop(),
            trailing: PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'practice',
                  child: Row(
                    children: [
                      Icon(Icons.quiz),
                      SizedBox(width: 8),
                      Text('Practice All'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Export Progress'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.upload),
                      SizedBox(width: 8),
                      Text('Import Progress'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Reset Progress', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Search and Filters
          _buildSearchAndFilters(),
          
          // Rules List
          Expanded(
            child: Consumer<DutchGrammarProvider>(
              builder: (context, provider, child) {
                final rules = provider.filteredRules;
                
                if (rules.isEmpty) {
                  return _buildEmptyState();
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    return _buildRuleCard(rules[index], provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startPractice(),
        icon: const Icon(Icons.quiz),
        label: const Text('Practice'),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search grammar rules...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        context.read<DutchGrammarProvider>().filterRules(
                          searchQuery: '',
                        );
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
            ),
            onChanged: (value) {
              context.read<DutchGrammarProvider>().filterRules(
                searchQuery: value,
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filters
          Row(
            children: [

              
              
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(DutchGrammarRule rule, DutchGrammarProvider provider) {
    final progress = provider.getRuleProgressPercentage(rule.id);
    final completedCount = provider.getRuleProgress(rule.id);
    final totalExercises = rule.exercises.length;
    final accuracy = provider.getRuleAccuracy(rule.id);
    final statistics = provider.getRuleStudyStatistics(rule.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openRuleDetail(rule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Statistics summary
                        if (statistics['totalSessions'] > 0) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${statistics['totalSessions']} sessions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.trending_up,
                                size: 14,
                                color: _getAccuracyColor(accuracy),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(accuracy * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getAccuracyColor(accuracy),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showRuleHistory(rule),
                        icon: const Icon(Icons.history),
                        tooltip: 'View study history',
                      ),
                      IconButton(
                        onPressed: () => _startRulePractice(rule),
                        icon: const Icon(Icons.quiz),
                        tooltip: 'Practice this rule',
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Progress
              if (totalExercises > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress >= 0.8 ? Colors.green : 
                          progress >= 0.5 ? Colors.orange : 
                          Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$completedCount/$totalExercises',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Key points preview
              if (rule.keyPoints.isNotEmpty) ...[
                Text(
                  'Key Points:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rule.keyPoints.take(2).join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

    Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Widget _buildHistorySheet(DutchGrammarRule rule) {
    final provider = context.read<DutchGrammarProvider>();
    final history = provider.getRecentStudyHistory(rule.id);
    final statistics = provider.getRuleStudyStatistics(rule.id);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Study History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Statistics summary
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Statistics',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatItem(
                            'Sessions',
                            '${statistics['totalSessions']}',
                            Icons.history,
                          ),
                          const SizedBox(width: 16),
                          _buildStatItem(
                            'Questions',
                            '${statistics['totalQuestions']}',
                            Icons.quiz,
                          ),
                          const SizedBox(width: 16),
                          _buildStatItem(
                            'Accuracy',
                            '${(statistics['overallAccuracy'] * 100).toInt()}%',
                            Icons.trending_up,
                            color: _getAccuracyColor(statistics['overallAccuracy']),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // History list
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No study history yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Complete exercises to see your progress',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final session = history[index];
                      return _buildHistoryItem(session);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(GrammarStudySession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(session.date),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatTime(session.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Session details
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.quiz,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${session.totalQuestions} questions',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 16,
                      color: _getAccuracyColor(session.accuracy),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(session.accuracy * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getAccuracyColor(session.accuracy),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No grammar rules found',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
              context.read<DutchGrammarProvider>().clearFilters();
            },
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    context.read<DutchGrammarProvider>().filterRules(
      searchQuery: _searchController.text,
    );
  }

  void _openRuleDetail(DutchGrammarRule rule) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchGrammarRuleDetailView(rule: rule),
      ),
    );
  }

  void _startRulePractice(DutchGrammarRule rule) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchGrammarExerciseView(
          exercises: rule.exercises,
          ruleTitle: rule.title,
          ruleId: rule.id,
        ),
      ),
    );
  }

  void _showRuleHistory(DutchGrammarRule rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildHistorySheet(rule),
    );
  }

  void _startPractice() {
    final provider = context.read<DutchGrammarProvider>();
    final exercises = provider.getMixedExercises(count: 10);
    
    if (exercises.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DutchGrammarExerciseView(
            exercises: exercises,
            ruleTitle: 'Mixed Practice',
            ruleId: 'mixed_practice',
          ),
        ),
      );
    }
  }

  void _handleMenuAction(String action) {
    final provider = context.read<DutchGrammarProvider>();
    
    switch (action) {
      case 'practice':
        _startPractice();
        break;
      case 'export':
        _exportProgress(provider);
        break;
      case 'import':
        _importProgress(provider);
        break;
      case 'reset':
        _showResetConfirmation(provider);
        break;
    }
  }

  void _exportProgress(DutchGrammarProvider provider) {
    final data = provider.exportData();
    // TODO: Implement actual export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon!')),
    );
  }

  void _importProgress(DutchGrammarProvider provider) {
    // TODO: Implement actual import functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality coming soon!')),
    );
  }

  void _showResetConfirmation(DutchGrammarProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'Are you sure you want to reset all your grammar progress? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.resetProgress();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Progress reset successfully')),
              );
            },
            style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
