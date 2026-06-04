import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/deck.dart';
import 'study_type_selection_view.dart';
import 'connect_cards_view.dart';

import 'advanced_study_view.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'writing_view.dart';
import 'word_scramble_view.dart';
import 'add_card_view.dart';
import 'photo_import_view.dart';

import '../services/sample_data_service.dart';
import 'shuffle_cards_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    // Begin.wav sound is already played in AppInitializationView when app starts
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<FlashcardProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (provider.cards.isEmpty)
                  _buildEmptyState(context, provider)
                else
                  _buildFlashCardStudiesSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, FlashcardProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.teal.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Taal Trek!',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Add Dutch flashcards to unlock all 14 game modes.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _addSampleData(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Load 20 Sample Dutch Cards'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToAddCard(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Card Manually'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _navigateToPhotoImport(context),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Import from Photo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashCardStudiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flash Card Games',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuButtonWithInfo(
          'Study your cards',
          Icons.school,
          Colors.teal,
          () => _navigateToStudy(context),
          'Review your flashcards in a traditional format. Cards are shown one at a time with the Dutch word first, then reveal the English translation.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Test your cards',
          Icons.quiz,
          Colors.orange,
          () => _navigateToTest(context),
          'Challenge yourself with multiple choice questions. Choose the correct English translation for each Dutch word.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'True or false',
          Icons.help_outline,
          const Color(0xFFFF6B4D),
          () => _navigateToTrueFalse(context),
          'Test your knowledge with true/false statements. Determine if the Dutch word matches the English translation.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Remember your cards',
          Icons.psychology,
          Colors.orange,
          () => _navigateToMemoryGame(context),
          'Play a memory matching game. Find pairs of Dutch words and their English translations by remembering their positions.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Jumble your cards',
          Icons.abc,
          Colors.green,
          () => _navigateToJumble(context),
          'Unscramble the Dutch word from a jumble of letters. You must choose the correct translation and then arrange the letters in the correct order.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Connect your cards',
          Icons.grid_on,
          Colors.purple,
          () => _navigateToConnectCards(context),
          'Connect letters in a grid to spell Dutch words. Drag to connect adjacent letters and form the correct translation.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Write your card',
          Icons.edit,
          Colors.blue,
          () => _navigateToWriting(context),
          'Practice writing Dutch words from memory. Type the Dutch word that matches the English translation.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Sentence your cards',
          Icons.reorder,
          Colors.blueGrey,
          () => _navigateToSentenceBuilding(context),
          'Build full sentences by putting words in the correct order. Practice using Dutch words in context with their example sentences.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'De of Het',
          Icons.article,
          const Color(0xFF1565C0),
          () => _navigateToDeHet(context),
          'Practice Dutch articles! See a word and decide if it takes "de" or "het". Only cards with an article set will appear.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'So Many Cards',
          Icons.library_add,
          const Color(0xFFFF9800),
          () => _navigateToSoManyCards(context),
          'Master Dutch plurals! Identify the correct plural form of nouns using common patterns like -en, -s, and more.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Time Your Cards',
          Icons.timer,
          const Color(0xFFE91E63),
          () => _navigateToTimeYourCards(context),
          'Practice Dutch verb tenses! Identify the correct present, past, or perfect tense for a given verb.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Shuffle Your Cards',
          Icons.shuffle,
          Colors.purple,
          () => _navigateToShuffleCards(context),
          'Randomize the order of your cards for a fresh study experience. Great for breaking up memorization patterns.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Pick Your Card',
          Icons.tune,
          Colors.indigo,
          () => _navigateToPickYourCard(context),
          'Use spinning wheels to select the correct word pieces and build the Dutch translation. Each wheel contains similar letter combinations.',
        ),
        const SizedBox(height: 12),
        _buildMenuButtonWithInfo(
          'Pop Your Card',
          Icons.bubble_chart,
          Colors.cyan,
          () => _navigateToPopYourCard(context),
          'Tap the correct floating word bubble while avoiding decoy variants. Words bounce around the screen with physics!',
        ),
      ],
    );
  }

  Widget _buildMenuButtonWithInfo(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
    String description,
  ) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 72, // Fixed height to match cards screen
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () =>
                      _showStudyModeInfo(context, title, description),
                  icon: Icon(
                    Icons.info_outline,
                    size: 20,
                    color: color.withOpacity(0.7),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToStudy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) => StudyTypeSelectionView(gameMode: GameMode.study),
      ),
    );
  }

  void _navigateToTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) => StudyTypeSelectionView(gameMode: GameMode.test),
      ),
    );
  }

  void _navigateToTrueFalse(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.trueFalse),
      ),
    );
  }

  void _navigateToWriting(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) => StudyTypeSelectionView(gameMode: GameMode.write),
      ),
    );
  }

  void _navigateToDeHet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) => StudyTypeSelectionView(gameMode: GameMode.deHet),
      ),
    );
  }

  void _navigateToSoManyCards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.soManyCards),
      ),
    );
  }

  void _navigateToTimeYourCards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.timeYourCards),
      ),
    );
  }

  void _navigateToSentenceBuilding(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.sentenceBuilding),
      ),
    );
  }

  void _navigateToMemoryGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) => StudyTypeSelectionView(gameMode: GameMode.game),
      ),
    );
  }

  void _navigateToJumble(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.wordScramble),
      ),
    );
  }

  void _navigateToConnectCards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.connectCards),
      ),
    );
  }

  void _navigateToShuffleCards(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ShuffleCardsView()));
  }

  void _navigateToPickYourCard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.pickYourCard),
      ),
    );
  }

  void _navigateToPopYourCard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/options'),
        builder: (context) =>
            StudyTypeSelectionView(gameMode: GameMode.popYourCard),
      ),
    );
  }

  void _showStudyModeInfo(
    BuildContext context,
    String title,
    String description,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAddCard(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCardView()));
  }

  void _navigateToPhotoImport(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PhotoImportView()));
  }

  void _addSampleData(BuildContext context) async {
    final provider = context.read<FlashcardProvider>();
    await SampleDataService.addSampleData(provider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample Dutch vocabulary added!')),
    );
  }
}
