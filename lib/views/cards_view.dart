import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/phrase_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import 'all_cards_view.dart';
import 'all_decks_view.dart';
import 'photo_import_view.dart';
import 'phrases_list_view.dart';
import 'dutch_words_view.dart';
import 'dutch_grammar_rules_view.dart';
import 'bubble_word_map_selection_view.dart';
import 'store_view.dart';

class CardsView extends StatefulWidget {
  const CardsView({super.key});

  @override
  State<CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<CardsView> {
  bool _showingAddCardView = false;
  bool _showingAddDeckView = false;
  bool _showingCardsInfoView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<FlashcardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildContent(context, provider);
        },
      ),
    );
  }



  Widget _buildContent(BuildContext context, FlashcardProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Section
          _buildStatsSection(context, provider),
          const SizedBox(height: 20),
          
          // Add Section
          _buildAddSection(context),
          const SizedBox(height: 20),
          
          // View Section
          _buildViewSection(context, provider),
          const SizedBox(height: 20),
          
          // Resources Section
          _buildResourcesSection(),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, FlashcardProvider provider) {
    final allCards = provider.cards;
    final allDecks = provider.getAllDecksHierarchical();
    
    print('🔍 CardsView: Building stats section with ${allCards.length} cards and ${allDecks.length} decks');
    
    // Calculate average learning percentage for cards
    final averageCardProgress = allCards.isEmpty 
        ? 0 
        : _calculateAverageCardProgress(allCards);
    
    // Calculate average learning percentage for decks
    final averageDeckProgress = allDecks.isEmpty 
        ? 0 
        : _calculateOverallDeckProgress(context, allDecks);
    
    print('🔍 CardsView: Displaying - Cards: ${averageCardProgress}%, Decks: ${averageDeckProgress}%');
    
    return Row(
      children: [
        // Total Cards with Progress
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Text(
                  '${allCards.length}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cards',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$averageCardProgress% learned',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Total Decks with Progress
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Text(
                  '${allDecks.length}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decks',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$averageDeckProgress% learned',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Import',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        
        // Import from Photo
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showPhotoImportDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shadowColor: Colors.blue.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Import from Photo',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewSection(BuildContext context, FlashcardProvider provider) {
    final allCards = provider.cards;
    final allDecks = provider.getAllDecksHierarchical();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'View',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        
        // View All Cards
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () => _viewAllCards(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shadowColor: Colors.blue.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.style,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                                    Text(
                      'Cards',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                const Spacer(),
                Text(
                  '(${allCards.length})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // View All Decks
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () => _viewAllDecks(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shadowColor: Colors.green.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 12),
                                    Text(
                      'Decks',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                const Spacer(),
                Text(
                  '(${allDecks.length})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // View All Exercises
        Consumer<DutchWordExerciseProvider>(
          builder: (context, exerciseProvider, child) {
            final allExercises = exerciseProvider.wordExercises;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                onPressed: () => _viewAllExercises(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 2,
                  shadowColor: Colors.indigo.withOpacity(0.2),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.quiz,
                      color: Colors.indigo,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                                         Text(
                       'Exercises',
                       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                         fontWeight: FontWeight.w500,
                       ),
                     ),
                    const Spacer(),
                    Text(
                      '(${allExercises.length})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        
        // View All Phrases
        Consumer<PhraseProvider>(
          builder: (context, phraseProvider, child) {
            final allPhrases = phraseProvider.phrases;
            return Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _viewAllPhrases(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  elevation: 2,
                  shadowColor: Colors.teal.withOpacity(0.2),
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      color: Colors.teal,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Phrases',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '(${allPhrases.length})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }



  Widget _buildResourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resources',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        
        // Grammar Rules
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () => _navigateToGrammar(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shadowColor: Colors.indigo.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: Colors.indigo,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Grammar Rules',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        
        // Bubble Word
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () => _navigateToBubbleWord(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shadowColor: Colors.purple.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bubble_chart,
                  color: Colors.purple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bubble Word',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
        
        // Store
        Container(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _navigateToStore(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              elevation: 2,
              shadowColor: Colors.orange.withOpacity(0.2),
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Store',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPhotoImportDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PhotoImportView(),
      ),
    );
  }

  void _viewAllCards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AllCardsView(),
      ),
    );
  }

  void _viewAllDecks(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AllDecksView(),
      ),
    );
  }

  void _viewAllExercises(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DutchWordsView(),
      ),
    );
  }

  void _viewAllPhrases(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PhrasesListView(),
      ),
    );
  }

  void _navigateToGrammar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DutchGrammarRulesView(),
      ),
    );
  }

  void _navigateToBubbleWord(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BubbleWordMapSelectionView(),
      ),
    );
  }

  void _navigateToStore(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoreView(),
      ),
    );
  }

  void _showCardsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Add Cards'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Tap "Add New Card" to create a new flashcard'),
            SizedBox(height: 8),
            Text('2. Fill in the word and definition'),
            SizedBox(height: 8),
            Text('3. Select which deck(s) to add it to'),
            SizedBox(height: 8),
            Text('4. Add optional details like examples'),
            SizedBox(height: 8),
            Text('5. Tap "Create Card" to save'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  int _calculateAverageCardProgress(List<FlashCard> cards) {
    if (cards.isEmpty) return 0;
    
    double totalProgress = 0.0;
    for (final card in cards) {
      totalProgress += card.learningPercentage.toDouble();
    }
    final averageProgress = totalProgress / cards.length;
    
    return averageProgress.round();
  }
  
  int _calculateOverallDeckProgress(BuildContext context, List<Deck> decks) {
    print('🔍 CardsView: Calculating deck progress for ${decks.length} decks');
    
    if (decks.isEmpty) {
      print('🔍 CardsView: No decks, returning 0%');
      return 0;
    }
    
    // Calculate percentage of decks that are 100% learned
    int fullyLearnedDecks = 0;
    
    for (final deck in decks) {
      // Get the actual cards for this deck from the provider
      final deckCards = context.read<FlashcardProvider>().getCardsForDeck(deck.id);
      print('🔍 CardsView: Checking deck "${deck.name}" with ${deckCards.length} cards');
      
      if (deckCards.isNotEmpty) {
        double deckProgress = Deck.calculateLearningPercentage(deck.name, deckCards);
        print('🔍 CardsView: Deck "${deck.name}" has ${deckProgress}% progress');
        
        if (deckProgress >= 100.0) {
          fullyLearnedDecks++;
          print('🔍 CardsView: Deck "${deck.name}" is fully learned! (${fullyLearnedDecks} total)');
        }
      } else {
        print('🔍 CardsView: Deck "${deck.name}" is empty');
      }
    }
    
    final percentageOfFullyLearnedDecks = (fullyLearnedDecks / decks.length) * 100;
    print('🔍 CardsView: Final calculation: $fullyLearnedDecks fully learned / ${decks.length} total = ${percentageOfFullyLearnedDecks}%');
    
    return percentageOfFullyLearnedDecks.round();
  }
} 