import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/flashcard_provider.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';

class SampleDataService {
  static const String _sampleDataKey = 'sample_data_offered';
  
  static final List<Map<String, String>> _sampleCards = [
    {
      'word': 'huis',
      'definition': 'house',
      'example': 'Ik woon in een groot huis.',
      'article': 'het',
      'plural': 'huizen',
    },
    {
      'word': 'auto',
      'definition': 'car',
      'example': 'Ik rijd in een nieuwe auto.',
      'article': 'de',
      'plural': 'auto\'s',
    },
    {
      'word': 'boek',
      'definition': 'book',
      'example': 'Ik lees een interessant boek.',
      'article': 'het',
      'plural': 'boeken',
    },
    {
      'word': 'hond',
      'definition': 'dog',
      'example': 'Mijn hond heet Max.',
      'article': 'de',
      'plural': 'honden',
    },
    {
      'word': 'kat',
      'definition': 'cat',
      'example': 'De kat slaapt op de bank.',
      'article': 'de',
      'plural': 'katten',
    },
    {
      'word': 'man',
      'definition': 'man',
      'example': 'Die man is mijn vader.',
      'article': 'de',
      'plural': 'mannen',
    },
    {
      'word': 'vrouw',
      'definition': 'woman',
      'example': 'Die vrouw is mijn moeder.',
      'article': 'de',
      'plural': 'vrouwen',
    },
    {
      'word': 'kind',
      'definition': 'child',
      'example': 'Het kind speelt in de tuin.',
      'article': 'het',
      'plural': 'kinderen',
    },
    {
      'word': 'water',
      'definition': 'water',
      'example': 'Ik drink veel water.',
      'article': 'het',
      'plural': 'waters',
    },
    {
      'word': 'brood',
      'definition': 'bread',
      'example': 'Ik eet vers brood.',
      'article': 'het',
      'plural': 'broden',
    },
    {
      'word': 'kaas',
      'definition': 'cheese',
      'example': 'Ik hou van Nederlandse kaas.',
      'article': 'de',
      'plural': 'kazen',
    },
    {
      'word': 'melk',
      'definition': 'milk',
      'example': 'Ik drink melk bij het ontbijt.',
      'article': 'de',
      'plural': 'melken',
    },
    {
      'word': 'appel',
      'definition': 'apple',
      'example': 'Ik eet een rode appel.',
      'article': 'de',
      'plural': 'appels',
    },
    {
      'word': 'fiets',
      'definition': 'bicycle',
      'example': 'Ik fiets naar school.',
      'article': 'de',
      'plural': 'fietsen',
    },
    {
      'word': 'school',
      'definition': 'school',
      'example': 'Mijn kinderen gaan naar school.',
      'article': 'de',
      'plural': 'scholen',
    },
    // Adding more cards to get closer to 20
    {
      'word': 'zijn',
      'definition': 'to be',
      'example': 'Ik ben student.',
      'article': '',
      'plural': '',
      'pastTense': 'was',
      'futureTense': 'zal zijn',
      'pastParticiple': 'geweest',
    },
    {
      'word': 'hebben',
      'definition': 'to have',
      'example': 'Ik heb een hond.',
      'article': '',
      'plural': '',
      'pastTense': 'had',
      'futureTense': 'zal hebben',
      'pastParticiple': 'gehad',
    },
    {
      'word': 'doen',
      'definition': 'to do',
      'example': 'Wat doe je vandaag?',
      'article': '',
      'plural': '',
      'pastTense': 'deed',
      'futureTense': 'zal doen',
      'pastParticiple': 'gedaan',
    },
    {
      'word': 'gaan',
      'definition': 'to go',
      'example': 'Ik ga naar huis.',
      'article': '',
      'plural': '',
      'pastTense': 'ging',
      'futureTense': 'zal gaan',
      'pastParticiple': 'gegaan',
    },
    {
      'word': 'komen',
      'definition': 'to come',
      'example': 'Kom je naar het feest?',
      'article': '',
      'plural': '',
      'pastTense': 'kwam',
      'futureTense': 'zal komen',
      'pastParticiple': 'gekomen',
    },
  ];

  static Future<void> addSampleData(FlashcardProvider provider) async {
    // Check if "Dutch Basics" deck already exists
    final existingDeck = provider.decks.firstWhere(
      (deck) => deck.name == 'Dutch Basics',
      orElse: () => Deck(id: '', name: '', cards: [], dateCreated: DateTime.now()),
    );
    
    Deck? deck;
    if (existingDeck.id.isEmpty) {
      // Create a new sample deck only if it doesn't exist
      deck = await provider.createDeck('Dutch Basics');
    } else {
      deck = existingDeck;
    }
    
    // Only add cards if the deck is empty
    if (deck != null && provider.getCardsForDeck(deck.id).isEmpty) {
      // Add sample cards to the deck
      for (final cardData in _sampleCards) {
        await provider.createCard(
          word: cardData['word']!,
          definition: cardData['definition']!,
          example: cardData['example']!,
          article: cardData['article']!,
          plural: cardData['plural']!,
          pastTense: cardData['pastTense'] ?? '',
          futureTense: cardData['futureTense'] ?? '',
          pastParticiple: cardData['pastParticiple'] ?? '',
          deckIds: {deck.id},
        );
      }
    }
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
    return hasOffered != true; // Return true if we haven't offered yet
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
                  await addSampleData(provider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sample Dutch vocabulary added! You can now start studying.'),
                        duration: Duration(seconds: 3),
                      ),
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