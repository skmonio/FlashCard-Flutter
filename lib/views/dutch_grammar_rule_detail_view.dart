import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dutch_grammar_rule.dart';
import '../providers/dutch_grammar_provider.dart';
import '../components/unified_header.dart';
import 'dutch_grammar_exercise_view.dart';

class DutchGrammarRuleDetailView extends StatefulWidget {
  final DutchGrammarRule rule;

  const DutchGrammarRuleDetailView({
    super.key,
    required this.rule,
  });

  @override
  State<DutchGrammarRuleDetailView> createState() => _DutchGrammarRuleDetailViewState();
}

class _DutchGrammarRuleDetailViewState extends State<DutchGrammarRuleDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
            title: widget.rule.title,
            onBack: () => Navigator.of(context).pop(),
            trailing: IconButton(
              onPressed: () => _startPractice(),
              icon: const Icon(Icons.quiz),
              tooltip: 'Practice this rule',
            ),
          ),
          
          // Rule Info
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress indicator (moved to the right)
                Row(
                  children: [
                    const Spacer(),
                    Consumer<DutchGrammarProvider>(
                      builder: (context, provider, child) {
                        final progress = provider.getRuleProgressPercentage(widget.rule.id);
                        final completedCount = provider.getRuleProgress(widget.rule.id);
                        final totalExercises = widget.rule.exercises.length;
                        
                        return Row(
                          children: [
                            if (totalExercises > 0) ...[
                              Text(
                                '$completedCount/$totalExercises',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 60,
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
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Key Points
                if (widget.rule.keyPoints.isNotEmpty) ...[
                  Text(
                    'Key Points:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.rule.keyPoints.map((point) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                        Expanded(child: SelectableText(
                          point, 
                          textAlign: TextAlign.left, 
                          enableInteractiveSelection: true, 
                          showCursor: false,
                          contextMenuBuilder: (context, editableTextState) {
                            return const SizedBox.shrink(); // Hide context menu
                          },
                        )),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Explanation'),
                Tab(text: 'Examples'),
                Tab(text: 'Exercises'),
                Tab(text: 'Tips'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExplanationTab(),
                _buildExamplesTab(),
                _buildExercisesTab(),
                _buildTipsTab(),
              ],
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

  Widget _buildExplanationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            widget.rule.explanation,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.left,
            enableInteractiveSelection: true,
            showCursor: false,
            contextMenuBuilder: (context, editableTextState) {
              return const SizedBox.shrink(); // Hide context menu
            },
          ),
          
          if (widget.rule.relatedRules.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Related Rules:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.rule.relatedRules.map((ruleId) {
                final relatedRule = context.read<DutchGrammarProvider>().getRuleById(ruleId);
                if (relatedRule == null) return const SizedBox.shrink();
                
                return ActionChip(
                  label: Text(relatedRule.title),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => DutchGrammarRuleDetailView(rule: relatedRule),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExamplesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.rule.examples.length,
      itemBuilder: (context, index) {
        final example = widget.rule.examples[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dutch text
                SelectableText(
                  example.dutch,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.left,
                  enableInteractiveSelection: true,
                  showCursor: false,
                  contextMenuBuilder: (context, editableTextState) {
                    return const SizedBox.shrink(); // Hide context menu
                  },
                ),
                
                const SizedBox(height: 8),
                
                // English translation
                SelectableText(
                  example.english,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.left,
                  enableInteractiveSelection: true,
                  showCursor: false,
                  contextMenuBuilder: (context, editableTextState) {
                    return const SizedBox.shrink(); // Hide context menu
                  },
                ),
                
                if (example.breakdown != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      example.breakdown!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.left,
                      enableInteractiveSelection: true,
                      showCursor: false,
                      contextMenuBuilder: (context, editableTextState) {
                        return const SizedBox.shrink(); // Hide context menu
                      },
                    ),
                  ),
                ],
                
                if (example.audioHint != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.volume_up,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        example.audioHint!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercisesTab() {
    return Column(
      children: [
        // Exercise count and start button
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.rule.exercises.length} Exercises',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Practice this grammar rule with interactive exercises',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _startPractice(),
                icon: const Icon(Icons.quiz),
                label: const Text('Start'),
              ),
            ],
          ),
        ),
        
        // Exercise preview list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.rule.exercises.length,
            itemBuilder: (context, index) {
              final exercise = widget.rule.exercises[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getExerciseTypeColor(exercise.exerciseType),
                    child: Icon(
                      _getExerciseTypeIcon(exercise.exerciseType),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    exercise.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _getExerciseTypeName(exercise.exerciseType),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _startSingleExercise(exercise, index),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTipsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tips
        if (widget.rule.tips.isNotEmpty) ...[
          Text(
            'Learning Tips:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.rule.tips.map((tip) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tip)),
                ],
              ),
            ),
          )),
          const SizedBox(height: 24),
        ],
        
        // Common Mistakes
        if (widget.rule.commonMistakes.isNotEmpty) ...[
          Text(
            'Common Mistakes:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.rule.commonMistakes.map((mistake) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.close, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mistake.incorrect,
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mistake.correct,
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mistake.explanation,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }

  // Removed type and level chips as requested by user

  void _startPractice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchGrammarExerciseView(
          exercises: widget.rule.exercises,
          ruleTitle: widget.rule.title,
          ruleId: widget.rule.id,
        ),
      ),
    );
  }

  void _startSingleExercise(GrammarExercise exercise, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DutchGrammarExerciseView(
          exercises: [exercise],
          ruleTitle: widget.rule.title,
          ruleId: widget.rule.id,
          startIndex: 0,
        ),
      ),
    );
  }

  // Removed type and level helper methods as they are no longer needed

  String _getExerciseTypeName(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return 'Multiple Choice';
      case ExerciseType.translation:
        return 'Translation';
      case ExerciseType.fillInTheBlank:
        return 'Fill in the Blank';
      case ExerciseType.sentenceOrder:
        return 'Sentence Order';
      case ExerciseType.trueFalse:
        return 'True/False';
    }
  }

  IconData _getExerciseTypeIcon(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Icons.format_list_bulleted;
      case ExerciseType.translation:
        return Icons.translate;
      case ExerciseType.fillInTheBlank:
        return Icons.edit;
      case ExerciseType.sentenceOrder:
        return Icons.sort;
      case ExerciseType.trueFalse:
        return Icons.check_circle_outline;
    }
  }

  Color _getExerciseTypeColor(ExerciseType type) {
    switch (type) {
      case ExerciseType.multipleChoice:
        return Colors.blue;
      case ExerciseType.translation:
        return Colors.green;
      case ExerciseType.fillInTheBlank:
        return Colors.orange;
      case ExerciseType.sentenceOrder:
        return Colors.purple;
      case ExerciseType.trueFalse:
        return Colors.teal;
    }
  }
}
