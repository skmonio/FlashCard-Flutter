import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/store_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/store_pack.dart';
import '../models/dutch_word_exercise.dart';
import '../models/flash_card.dart';

import 'store_pack_detail_view.dart';

class StoreView extends StatefulWidget {
  const StoreView({Key? key}) : super(key: key);

  @override
  State<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<StoreView> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDifficulty = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Pagination for search results
  static const int _searchResultsPerPage = 50;
  int _currentSearchPage = 0;
  List<Map<String, dynamic>> _allSearchResults = [];
  bool _hasMoreSearchResults = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final storeProvider = context.read<StoreProvider>();
      final flashcardProvider = context.read<FlashcardProvider>();
      await storeProvider.initialize();
      await storeProvider.validateUnlockedPacks(flashcardProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Store'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Card Packs'),
            Tab(text: 'Exercises'),
            Tab(text: 'Sentences'),
          ],
        ),
      ),
      body: Consumer<StoreProvider>(
        builder: (context, storeProvider, child) {
          if (storeProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (storeProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading store',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    storeProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => storeProvider.initialize(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for words...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                      // Reset pagination when search query changes
                      _currentSearchPage = 0;
                      _allSearchResults.clear();
                      _hasMoreSearchResults = false;
                    });
                  },
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPackList(storeProvider.getPacksByCategory('vocabulary')),
                    _buildPackList(storeProvider.getPacksByCategory('exercises')),
                    _buildPackList(storeProvider.getPacksByCategory('sentences')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPackList(List<StorePack> packs) {
    // If there's a search query, show search results instead
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    if (packs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No packs available',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new vocabulary packs!',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: packs.length,
      itemBuilder: (context, index) {
        final pack = packs[index];
        return _buildPackCard(pack);
      },
    );
  }

  Widget _buildPackCard(StorePack pack) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewPackContents(pack),
        borderRadius: BorderRadius.circular(12),
        child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: pack.unlocked
              ? LinearGradient(
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade100,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pack.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: pack.unlocked ? Colors.green.shade800 : null,
                                ),
                              ),
                            ),
                            if (pack.unlocked)
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade600,
                                size: 24,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pack.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildCardCountChip(pack.cardCount, pack.category),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }



  Widget _buildCardCountChip(int cardCount, String category) {
    Color color;
    IconData icon;
    String label;
    
    switch (category) {
      case 'vocabulary':
        color = Colors.blue;
        icon = Icons.style;
        label = '$cardCount cards';
        break;
      case 'exercises':
        color = Colors.orange;
        icon = Icons.quiz;
        label = '$cardCount exercises';
        break;
      case 'sentences':
        color = Colors.teal;
        icon = Icons.chat_bubble;
        label = '$cardCount sentences';
        break;
      default:
        color = Colors.blue;
        icon = Icons.style;
        label = '$cardCount items';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getSearchResults(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading search results',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Get paginated results
        final startIndex = _currentSearchPage * _searchResultsPerPage;
        final endIndex = startIndex + _searchResultsPerPage;
        final paginatedResults = _allSearchResults.take(endIndex).toList();
        _hasMoreSearchResults = endIndex < _allSearchResults.length;
        
        if (paginatedResults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No words or exercises found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try searching for a different word',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Result count indicator
            if (_allSearchResults.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Showing ${paginatedResults.length} of ${_allSearchResults.length} results',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: paginatedResults.length + (_hasMoreSearchResults ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == paginatedResults.length) {
                    // Load more button
                    return _buildLoadMoreButton();
                  }
                  
                                    final result = paginatedResults[index];
                  final type = result['type'] as String;
            
            if (type == 'card') {
              final card = result['data'] as FlashCard;
              final deckNames = card.deckIds.map((deckId) {
                final deck = context.read<FlashcardProvider>().getDeck(deckId);
                return deck?.name ?? 'Unknown Deck';
              }).toList();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.word,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (card.article.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Article: ${card.article}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Card',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.definition,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (card.example.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          card.example,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Decks: ${deckNames.join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (type == 'exercise') {
              final exercise = result['data'] as Map<String, dynamic>;
              final word = exercise['word'] as String;
              final question = exercise['question'] as String;
              final packName = exercise['packName'] as String;
              final wordExists = exercise['wordExists'] as bool;
              final deckName = exercise['deckName'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _viewStoreExerciseDetails(exercise),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Exercise',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Question: $question',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From: $packName',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (wordExists && deckName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Word exists in: $deckName',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else if (!wordExists) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Word not found - add word first',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    ],
        );
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _currentSearchPage++;
          });
        },
        child: const Text('Load More Results'),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getSearchResults() async {
    final flashcardProvider = context.read<FlashcardProvider>();
    final exerciseProvider = context.read<DutchWordExerciseProvider>();
    final storeProvider = context.read<StoreProvider>();
    
    final matchingCards = flashcardProvider.cards.where((card) {
      return card.word.toLowerCase().contains(_searchQuery) ||
             card.definition.toLowerCase().contains(_searchQuery);
    }).toList();

        // For exercises, we need to search in the store packs, not local exercises
    final matchingExercises = <Map<String, dynamic>>[];
    
    // Search through all exercise packs in the store
    final exercisePacks = storeProvider.getPacksByCategory('exercises');
    for (final pack in exercisePacks) {
      try {
        // Load the pack contents to search through exercises
        final csvString = await rootBundle.loadString('assets/data/store_packs/${pack.filename}');
        final lines = csvString.split('\n').where((line) => line.trim().isNotEmpty).toList();
        
        if (lines.length < 2) continue; // No data rows
        
        final headers = _parseCSVLine(lines[0]);
        final packContents = <Map<String, dynamic>>[];

        for (int i = 1; i < lines.length; i++) {
          final fields = _parseCSVLine(lines[i]);
          if (fields.length >= headers.length) {
            final item = <String, dynamic>{};
            for (int j = 0; j < headers.length; j++) {
              item[headers[j]] = fields[j];
            }
            packContents.add(item);
          }
        }
        
        for (final item in packContents) {
          final word = item['Word']?.toString().toLowerCase() ?? '';
          final question = item['Question']?.toString().toLowerCase() ?? '';
          
          if (word.contains(_searchQuery) || question.contains(_searchQuery)) {
            // Check if this word already exists locally
            final existingCard = flashcardProvider.cards.where(
              (card) => card.word.toLowerCase() == word,
            ).firstOrNull;
            
            matchingExercises.add({
              'word': item['Word'] ?? '',
              'question': item['Question'] ?? '',
              'exerciseType': item['Exercise Type'] ?? '',
              'correctAnswer': item['Correct Answer'] ?? '',
              'options': item['Options'] ?? '',
              'explanation': item['Explanation'] ?? '',
              'packName': pack.name,
              'wordExists': existingCard != null,
              'deckName': existingCard != null 
                  ? flashcardProvider.getDeck(existingCard.deckIds.first)?.name ?? 'Unknown Deck'
                  : null,
            });
          }
        }
      } catch (e) {
        // Skip packs that can't be loaded
        continue;
      }
    }

    final allResults = <Map<String, dynamic>>[];
    
    // Add cards (limit to prevent memory issues)
    final maxResults = 1000; // Limit total results to prevent crashes
    int resultCount = 0;
    
    for (final card in matchingCards) {
      if (resultCount >= maxResults) break;
      allResults.add({
        'type': 'card',
        'data': card,
      });
      resultCount++;
    }
    
    // Add exercises (limit to prevent memory issues)
    for (final exercise in matchingExercises) {
      if (resultCount >= maxResults) break;
      allResults.add({
        'type': 'exercise',
        'data': exercise,
      });
      resultCount++;
    }

    // Store results for pagination
    _allSearchResults = allResults;
    _currentSearchPage = 0;
    
    // Show warning if results were limited
    if (allResults.length >= 1000) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Search results limited to 1000 items for performance. Try a more specific search term.'),
            duration: Duration(seconds: 3),
          ),
        );
      });
    }
    
    return allResults;
  }

  void _viewPackContents(StorePack pack) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StorePackDetailView(pack: pack),
      ),
    );
  }

  void _viewExerciseDetails(DutchWordExercise exercise) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exercises for "${exercise.targetWord}"'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: exercise.exercises.length,
            itemBuilder: (context, index) {
              final wordExercise = exercise.exercises[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: Text(
                                wordExercise.type.toString().split('.').last,
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Question:',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        wordExercise.prompt,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Answer: ${wordExercise.correctAnswer}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewStoreExerciseDetails(Map<String, dynamic> exercise) {
    try {
      final word = exercise['word'] as String? ?? '';
      final question = exercise['question'] as String? ?? '';
      final exerciseType = exercise['exerciseType'] as String? ?? '';
      final correctAnswer = exercise['correctAnswer'] as String? ?? '';
      final options = exercise['options'] as String? ?? '';
      final explanation = exercise['explanation'] as String? ?? '';
      final wordExists = exercise['wordExists'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exercise for "$word"'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  exerciseType,
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Question:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Answer:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                correctAnswer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (options.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Options:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  options,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (explanation.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Explanation:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  explanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              if (wordExists) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Word exists - you can import this exercise',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Word not found - add the word first before importing exercises',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (wordExists)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _importStoreExercise(exercise);
              },
              child: const Text('Import Exercise'),
            ),
        ],
      ),
    );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing exercise details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importStoreExercise(Map<String, dynamic> exercise) async {
    final exerciseProvider = context.read<DutchWordExerciseProvider>();
    final flashcardProvider = context.read<FlashcardProvider>();
    
    try {
      final word = exercise['word'] as String;
      final exerciseType = exercise['exerciseType'] as String;
      final question = exercise['question'] as String;
      final correctAnswer = exercise['correctAnswer'] as String;
      final options = exercise['options'] as String;
      final explanation = exercise['explanation'] as String;

      // Find existing card for this word
      final existingCard = flashcardProvider.cards.where(
        (card) => card.word.toLowerCase() == word.toLowerCase(),
      ).firstOrNull;

      if (existingCard == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word "$word" not found in any deck'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if exercise already exists for this word
      final existingExercise = exerciseProvider.wordExercises.where(
        (exercise) => exercise.targetWord.toLowerCase() == word.toLowerCase(),
      ).firstOrNull;

      final optionsList = options.isNotEmpty 
          ? options.split(';').map((e) => e.trim().toString()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      if (existingExercise != null) {
        // Add new exercise to existing word exercise
        final newWordExercise = WordExercise(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: _getExerciseType(exerciseType),
          prompt: question,
          options: optionsList,
          correctAnswer: correctAnswer,
          explanation: explanation,
          difficulty: ExerciseDifficulty.beginner,
        );
        
        final updatedExercise = DutchWordExercise(
          id: existingExercise.id,
          targetWord: existingExercise.targetWord,
          wordTranslation: existingExercise.wordTranslation,
          deckId: existingExercise.deckId,
          deckName: existingExercise.deckName,
          category: existingExercise.category,
          difficulty: existingExercise.difficulty,
          exercises: [...existingExercise.exercises, newWordExercise],
          createdAt: existingExercise.createdAt,
          isUserCreated: existingExercise.isUserCreated,
          learningProgress: existingExercise.learningProgress,
        );
        
        await exerciseProvider.updateWordExercise(updatedExercise);
      } else {
        // Create new word exercise
        final newExercise = DutchWordExercise(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          targetWord: word,
          wordTranslation: correctAnswer,
          deckId: existingCard.deckIds.first,
          deckName: flashcardProvider.getDeck(existingCard.deckIds.first)?.name ?? 'Unknown Deck',
          category: WordCategory.common,
          difficulty: ExerciseDifficulty.beginner,
          exercises: [
            WordExercise(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: _getExerciseType(exerciseType),
              prompt: question,
              options: optionsList,
              correctAnswer: correctAnswer,
              explanation: explanation,
              difficulty: ExerciseDifficulty.beginner,
            ),
          ],
          createdAt: DateTime.now(),
          isUserCreated: false,
          learningProgress: LearningProgress(),
        );
        
        await exerciseProvider.addWordExercise(newExercise);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported exercise for "$word"'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing exercise: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ExerciseType _getExerciseType(String exerciseType) {
    switch (exerciseType.toLowerCase()) {
      case 'multiple choice':
        return ExerciseType.multipleChoice;
      case 'fill in blank':
        return ExerciseType.fillInBlank;
      case 'sentence building':
        return ExerciseType.sentenceBuilding;
      case 'translation':
        return ExerciseType.translation;
      case 'true/false':
      case 'true false':
        return ExerciseType.trueFalse;
      default:
        return ExerciseType.multipleChoice;
    }
  }

  List<String> _parseCSVLine(String line) {
    final result = <String>[];
    String current = '';
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current.trim());
    return result;
  }

}
