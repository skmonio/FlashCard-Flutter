import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flash_card.dart';
import '../providers/flashcard_provider.dart';
import '../services/xp_service.dart';
import '../views/add_card_view.dart';
import 'hp_bar.dart';
import 'package:intl/intl.dart';

class CardDetailsDialog extends StatelessWidget {
  final FlashCard card;

  const CardDetailsDialog({
    super.key,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    // Get the fresh card data from the provider to ensure we have the latest XP and learning progress
    final provider = context.read<FlashcardProvider>();
    final freshCard = provider.getCard(card.id) ?? card;
    
    final xpService = XpService();
    final wordLevel = freshCard.learningMastery.rpgWordLevel;
    
    return AlertDialog(
      title: Row(
        children: [
          Text(
            freshCard.article.isNotEmpty ? '${freshCard.article} ' : '',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: Text(freshCard.word)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Word and Definition
              Text(
                freshCard.definition,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              // Deck Information
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Decks: ${_getDeckNames(freshCard, provider)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              // Plural (if exists)
              if (freshCard.plural.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Plural: ${freshCard.plural}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              
              const SizedBox(height: 16),
              
              // Card Level and XP Section
              Row(
                children: [
                  Text(
                    'Card Level: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    xpService.getLevelIcon(wordLevel),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Level ${wordLevel.level} (${wordLevel.title})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Current XP: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${freshCard.learningMastery.currentXPWithDecay}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (freshCard.learningMastery.xpNeededForNextLevel > 0) ...[
                    Text(
                      ' / ${wordLevel.maxXP} (${freshCard.learningMastery.xpNeededForNextLevel} to next level)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text('Learning Progress: ${freshCard.learningPercentage ?? 0}%'),
              const SizedBox(height: 8),
              
              // Study Statistics
              Text('Times Shown: ${freshCard.timesShown}'),
              Text('Times Correct: ${freshCard.timesCorrect}'),
              Text('Consecutive Correct: ${freshCard.consecutiveCorrect}'),
              const SizedBox(height: 8),
              
              // Next Review
              Row(
                children: [
                  Text(
                    'Next Review: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _getNextReviewText(freshCard),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              
              // Health Points (HP) Section
              Row(
                children: [
                  Text(
                    'HP ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${freshCard.currentHP}/${freshCard.maxHP}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: HPBar(
                      currentHP: freshCard.currentHP,
                      maxHP: freshCard.maxHP,
                      showText: false,
                      showStatus: false,
                    ),
                  ),
                ],
              ),
              
              // Dates
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Created: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(freshCard.dateCreated),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Last Modified: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM dd, yyyy').format(freshCard.lastModified),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Navigate to edit card screen
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AddCardView(
                  cardToEdit: freshCard,
                ),
              ),
            );
          },
          child: const Text('Edit'),
        ),
      ],
    );
  }

  String _getDeckNames(FlashCard card, FlashcardProvider provider) {
    if (card.deckIds.isEmpty) return 'No decks';
    
    final deckNames = card.deckIds
        .map((id) => provider.getDeck(id)?.name ?? 'Unknown')
        .where((name) => name.isNotEmpty)
        .toList();
    
    return deckNames.isEmpty ? 'No decks' : deckNames.join(', ');
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
}
