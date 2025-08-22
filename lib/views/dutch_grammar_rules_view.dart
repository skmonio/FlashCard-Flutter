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
  String _searchQuery = '';
  String _sortOption = 'A-Z';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DutchGrammarProvider>().clearFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header
          UnifiedHeader(
            title: 'Grammar',
            onBack: () => Navigator.of(context).pop(),
            trailing: PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
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
          
          // Search and filter section
          _buildSearchAndFilterSection(),
          
          // Rules List
          Expanded(
            child: Consumer<DutchGrammarProvider>(
              builder: (context, provider, child) {
                final rules = _getFilteredAndSortedRules(provider);
                
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

    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search bar
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search grammar',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort Button
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortOption = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'A-Z',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward),
                    SizedBox(width: 8),
                    Text('A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Z-A',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward),
                    SizedBox(width: 8),
                    Text('Z-A'),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortOption == 'A-Z' ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sortOption,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(DutchGrammarRule rule, DutchGrammarProvider provider) {
    final progress = provider.getRuleProgressPercentage(rule.id);
    final accuracy = provider.getRuleAccuracy(rule.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openRuleDetail(rule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Percentage on the left (like cards and decks)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getAccuracyColor(accuracy).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    '${(accuracy * 100).toInt()}%',
                    style: TextStyle(
                      color: _getAccuracyColor(accuracy),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Rule title
              Expanded(
                child: Text(
                  rule.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
                  _searchQuery = '';
                });
                context.read<DutchGrammarProvider>().clearFilters();
              },
              child: const Text('Clear Search'),
            ),
        ],
      ),
    );
  }



  void _openRuleDetail(DutchGrammarRule rule) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchGrammarRuleDetailView(rule: rule),
      ),
    );
  }



  void _handleMenuAction(String action) {
    final provider = context.read<DutchGrammarProvider>();
    
    switch (action) {
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

  List<DutchGrammarRule> _getFilteredAndSortedRules(DutchGrammarProvider provider) {
    var filteredRules = List<DutchGrammarRule>.from(provider.allRules);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filteredRules = filteredRules.where((rule) =>
        rule.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        rule.explanation.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    
    // Sort rules
    if (_sortOption == 'A-Z') {
      filteredRules.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else if (_sortOption == 'Z-A') {
      filteredRules.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    }
    
    return filteredRules;
  }
}
