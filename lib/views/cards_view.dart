import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/deck.dart';
import '../models/flash_card.dart';
import 'all_cards_view.dart';
import 'all_decks_view.dart';
import 'photo_import_view.dart';

class CardsView extends StatefulWidget {
  const CardsView({super.key});

  @override
  State<CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<CardsView> {
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
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, FlashcardProvider provider) {
    final allCards = provider.cards;
    final allDecks = provider.getAllDecksHierarchical();
    
    // Calculate average learning percentage for cards
    final averageCardProgress = allCards.isEmpty 
        ? 0 
        : _calculateAverageCardProgress(allCards);
    
    // Calculate average learning percentage for decks
    final averageDeckProgress = allDecks.isEmpty 
        ? 0 
        : _calculateOverallDeckProgress(context, allDecks);
    
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
                const Icon(
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
                const Icon(
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
                const Icon(
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
    if (decks.isEmpty) {
      return 0;
    }
    
    int fullyLearnedDecks = 0;
    
    for (final deck in decks) {
      final deckCards = context.read<FlashcardProvider>().getCardsForDeck(deck.id);
      
      if (deckCards.isNotEmpty) {
        double deckProgress = Deck.calculateLearningPercentage(deck.name, deckCards);
        
        if (deckProgress >= 100.0) {
          fullyLearnedDecks++;
        }
      }
    }
    
    final percentageOfFullyLearnedDecks = (fullyLearnedDecks / decks.length) * 100;
    return percentageOfFullyLearnedDecks.round();
  }
}