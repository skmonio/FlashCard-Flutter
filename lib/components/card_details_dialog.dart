import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flash_card.dart';
import '../providers/flashcard_provider.dart';
import '../services/xp_service.dart';
import '../utils/card_color_utils.dart';
import '../views/add_card_view.dart';
import '../views/card_stats_view.dart';
import 'hp_bar.dart';
import 'package:intl/intl.dart';

class CardDetailsDialog extends StatefulWidget {
  final FlashCard card;

  const CardDetailsDialog({
    super.key,
    required this.card,
  });

  @override
  State<CardDetailsDialog> createState() => _CardDetailsDialogState();
}

class _CardDetailsDialogState extends State<CardDetailsDialog> {
  @override
  Widget build(BuildContext context) {
    // Get the fresh card data from the provider to ensure we have the latest XP and learning progress
    final provider = context.watch<FlashcardProvider>();
    final freshCard = provider.getCard(widget.card.id) ?? widget.card;
    
    final xpService = XpService();
    final wordLevel = freshCard.learningMastery.rpgWordLevel;
    
    return Column(
      children: [
        // Handle bar for the bottom sheet
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Title section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                freshCard.article.isNotEmpty ? '${freshCard.article} ' : '',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 20,
                ),
              ),
              Expanded(
                child: Text(
                  freshCard.word,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Content section
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
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
                    'Decks: ${CardColorUtils.getDeckNames(freshCard, provider)}',
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
              Text('Learning Progress: ${freshCard.learningPercentage}%'),
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        
        // Action buttons at the bottom
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // First row of buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Navigate to detailed stats page
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CardStatsView(card: freshCard),
                          ),
                        );
                      },
                      icon: const Icon(Icons.analytics, size: 16),
                      label: const Text('Stats'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
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
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Second row of buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final provider = context.read<FlashcardProvider>();
                        try {
                          await provider.updateCardPublicStatus(
                            freshCard.id, 
                            !freshCard.isPublic
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  freshCard.isPublic 
                                    ? 'Card made private' 
                                    : 'Card made public'
                                ),
                                backgroundColor: freshCard.isPublic ? Colors.orange : Colors.green,
                              ),
                            );
                            // The dialog will automatically rebuild due to context.watch<FlashcardProvider>()
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update card: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        freshCard.isPublic ? Icons.public_off : Icons.public,
                        size: 16,
                      ),
                      label: Text(freshCard.isPublic ? 'Make Private' : 'Make Public'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: freshCard.isPublic ? Colors.orange : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
}
