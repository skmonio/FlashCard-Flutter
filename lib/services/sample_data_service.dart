import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';

class SampleDataResult {
  SampleDataResult({
    required this.newCardsCreated,
    required this.cardsReattached,
    required this.cardsAlreadyPresent,
    this.deckCreated = false,
  });

  final int newCardsCreated;
  final int cardsReattached;
  final int cardsAlreadyPresent;
  final bool deckCreated;

  int get totalChanges => newCardsCreated + cardsReattached;
  bool get madeChanges => totalChanges > 0 || deckCreated;
}

class SampleDataService {
  static const String _sampleDataKey = 'sample_data_offered';
  
  static final List<Map<String, String>> _sampleCards = [
    {
      'word': 'huis',
      'definition': 'house',
      'example': 'Ik woon in een groot huis.',
      'exampleTranslation': 'I live in a large house.',
      'article': 'het',
      'plural': 'huizen',
    },
    {
      'word': 'auto',
      'definition': 'car',
      'example': 'Ik rijd in een nieuwe auto.',
      'exampleTranslation': 'I drive in a new car.',
      'article': 'de',
      'plural': 'auto\'s',
    },
    {
      'word': 'boek',
      'definition': 'book',
      'example': 'Ik lees een interessant boek.',
      'exampleTranslation': 'I read an interesting book.',
      'article': 'het',
      'plural': 'boeken',
    },
    {
      'word': 'hond',
      'definition': 'dog',
      'example': 'Mijn hond heet Max.',
      'exampleTranslation': 'My dog is called Max.',
      'article': 'de',
      'plural': 'honden',
    },
    {
      'word': 'kat',
      'definition': 'cat',
      'example': 'De kat slaapt op de bank.',
      'exampleTranslation': 'The cat sleeps on the sofa.',
      'article': 'de',
      'plural': 'katten',
    },
    {
      'word': 'man',
      'definition': 'man',
      'example': 'Die man is mijn vader.',
      'exampleTranslation': 'That man is my father.',
      'article': 'de',
      'plural': 'mannen',
    },
    {
      'word': 'vrouw',
      'definition': 'woman',
      'example': 'Die vrouw is mijn moeder.',
      'exampleTranslation': 'That woman is my mother.',
      'article': 'de',
      'plural': 'vrouwen',
    },
    {
      'word': 'kind',
      'definition': 'child',
      'example': 'Het kind speelt in de tuin.',
      'exampleTranslation': 'The child plays in the garden.',
      'article': 'het',
      'plural': 'kinderen',
    },
    {
      'word': 'water',
      'definition': 'water',
      'example': 'Ik drink veel water.',
      'exampleTranslation': 'I drink a lot of water.',
      'article': 'het',
      'plural': 'waters',
    },
    {
      'word': 'brood',
      'definition': 'bread',
      'example': 'Ik eet vers brood.',
      'exampleTranslation': 'I eat fresh bread.',
      'article': 'het',
      'plural': 'broden',
    },
    {
      'word': 'kaas',
      'definition': 'cheese',
      'example': 'Ik hou van Nederlandse kaas.',
      'exampleTranslation': 'I love Dutch cheese.',
      'article': 'de',
      'plural': 'kazen',
    },
    {
      'word': 'melk',
      'definition': 'milk',
      'example': 'Ik drink melk bij het ontbijt.',
      'exampleTranslation': 'I drink milk at breakfast.',
      'article': 'de',
      'plural': 'melken',
    },
    {
      'word': 'appel',
      'definition': 'apple',
      'example': 'Ik eet een rode appel.',
      'exampleTranslation': 'I eat a red apple.',
      'article': 'de',
      'plural': 'appels',
    },
    {
      'word': 'fiets',
      'definition': 'bicycle',
      'example': 'Ik fiets naar school.',
      'exampleTranslation': 'I cycle to school.',
      'article': 'de',
      'plural': 'fietsen',
    },
    {
      'word': 'school',
      'definition': 'school',
      'example': 'Mijn kinderen gaan naar school.',
      'exampleTranslation': 'My children go to school.',
      'article': 'de',
      'plural': 'scholen',
    },
    {
      'word': 'zijn',
      'definition': 'to be',
      'example': 'Ik ben student.',
      'exampleTranslation': 'I am a student.',
      'article': '',
      'plural': '',
      'presentTense': 'ben',
      'pastTense': 'was',
      'perfectTense': 'geweest',
    },
    {
      'word': 'hebben',
      'definition': 'to have',
      'example': 'Ik heb een hond.',
      'exampleTranslation': 'I have a dog.',
      'article': '',
      'plural': '',
      'presentTense': 'heb',
      'pastTense': 'had',
      'perfectTense': 'gehad',
    },
    {
      'word': 'doen',
      'definition': 'to do',
      'example': 'Wat doe je vandaag?',
      'exampleTranslation': 'What are you doing today?',
      'article': '',
      'plural': '',
      'presentTense': 'doe',
      'pastTense': 'deed',
      'perfectTense': 'gedaan',
    },
    {
      'word': 'gaan',
      'definition': 'to go',
      'example': 'Ik ga naar huis.',
      'exampleTranslation': 'I am going home.',
      'article': '',
      'plural': '',
      'presentTense': 'ga',
      'pastTense': 'ging',
      'perfectTense': 'gegaan',
    },
    {
      'word': 'komen',
      'definition': 'to come',
      'example': 'Kom je naar het feest?',
      'exampleTranslation': 'Are you coming to the party?',
      'article': '',
      'plural': '',
      'presentTense': 'kom',
      'pastTense': 'kwam',
      'perfectTense': 'gekomen',
    },
  ];

  static Future<SampleDataResult> addSampleData(FlashcardProvider provider) async {
    const deckName = 'Dutch Basics';

    Deck? deck;
    for (final existing in provider.decks) {
      if (existing.name == deckName) {
        deck = existing;
        break;
      }
    }

    bool createdDeck = false;
    if (deck == null) {
      deck = await provider.createDeck(deckName);
      createdDeck = deck != null;
    }

    if (deck == null) {
      return SampleDataResult(
        newCardsCreated: 0,
        cardsReattached: 0,
        cardsAlreadyPresent: 0,
        deckCreated: createdDeck,
      );
    }

    final existingDeckCards =
        provider.getCardsForDeck(deck.id).map((card) => card.word.toLowerCase().trim()).toSet();

    int createdCount = 0;
    int reattachedCount = 0;
    int alreadyPresentCount = 0;

    for (final cardData in _sampleCards) {
      final word = cardData['word']!.trim();
      final normalizedWord = word.toLowerCase();

      if (existingDeckCards.contains(normalizedWord)) {
        alreadyPresentCount += 1;
        continue;
      }

      FlashCard? existingCard;
      for (final card in provider.cards) {
        if (card.word.toLowerCase().trim() == normalizedWord) {
          existingCard = card;
          break;
        }
      }

      if (existingCard != null) {
        if (!existingCard.deckIds.contains(deck.id)) {
          final updatedDeckIds = Set<String>.from(existingCard.deckIds)..add(deck.id);
          final updatedCard = existingCard.copyWith(deckIds: updatedDeckIds);
          final updated = await provider.updateCard(updatedCard);
          if (updated) {
            reattachedCount += 1;
            existingDeckCards.add(normalizedWord);
          }
        } else {
          alreadyPresentCount += 1;
        }
        continue;
      }

      await provider.createCard(
        word: word,
        definition: cardData['definition']!,
        example: cardData['example']!,
        exampleTranslation: cardData['exampleTranslation'] ?? '',
        article: cardData['article'] ?? '',
        plural: cardData['plural'] ?? '',
        presentTense: cardData['presentTense'] ?? '',
        pastTense: cardData['pastTense'] ?? '',
        perfectTense: cardData['perfectTense'] ?? '',
        deckIds: {deck.id},
      );
      createdCount += 1;
      existingDeckCards.add(normalizedWord);
    }

    return SampleDataResult(
      newCardsCreated: createdCount,
      cardsReattached: reattachedCount,
      cardsAlreadyPresent: alreadyPresentCount,
      deckCreated: createdDeck,
    );
  }

  static Future<void> addSampleDataIfEmpty(FlashcardProvider provider) async {
    if (provider.cards.isEmpty) {
      await addSampleData(provider);
    }
  }
  
  // Check if we should show the sample data prompt
  static Future<bool> shouldShowSampleDataPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final hasOffered = prefs.getBool(_sampleDataKey);
    
    // Don't show if we've already offered
    if (hasOffered == true) {
      return false;
    }
    
    // Don't show if user already has cards
    final cards = prefs.getStringList('cards') ?? [];
    if (cards.isNotEmpty) {
      return false;
    }
    
    // Don't show if user has custom decks (not just system decks)
    final decks = prefs.getStringList('decks') ?? [];
    for (final deckJson in decks) {
      try {
        final deckData = json.decode(deckJson);
        final deckName = deckData['name'] as String?;
        if (deckName != null && deckName != 'Uncategorized' && deckName != 'Review') {
          return false; // User has custom decks, don't show sample prompt
        }
      } catch (e) {
        // If we can't parse, assume it's custom data
        return false;
      }
    }
    
    return true; // Show prompt only if no data exists
  }
  
  // Show sample data prompt dialog
  static Future<void> showSampleDataPrompt(BuildContext context, FlashcardProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Mark that we've offered sample data
    await prefs.setBool(_sampleDataKey, true);
    
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Welcome to Taal Trek!'),
            content: const Text(
              'Would you like to start with some sample Dutch vocabulary cards? '
              'This will help you understand how the app works. You can always add your own cards later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('No, thanks'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final result = await addSampleData(provider);
                  if (context.mounted) {
                    String message;
                    if (result.totalChanges > 0) {
                      message = 'Sample Dutch vocabulary added to your decks!';
                    } else {
                      message = 'Sample Dutch vocabulary is already in your decks.';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
                    );
                  }
                },
                child: const Text('Yes, please!'),
              ),
            ],
          );
        },
      );
    }
  }
} 