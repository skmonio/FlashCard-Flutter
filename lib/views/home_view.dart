import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../models/deck.dart';
import 'study_type_selection_view.dart';
import 'memory_game_view.dart';
import 'bubble_word_view.dart';

import 'advanced_study_view.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'writing_view.dart';
import 'word_scramble_view.dart';

import '../services/sample_data_service.dart';
import 'shuffle_cards_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Flash Card Studies Section
            _buildFlashCardStudiesSection(),
          ],
        ),
      ),
    );
  }



  Widget _buildFlashCardStudiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Flash Card Studies',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuButton(
          'Study your cards',
          Icons.school,
          Colors.teal,
          () => _navigateToStudy(context),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          'Test your cards',
          Icons.quiz,
          Colors.orange,
          () => _navigateToTest(context),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          'True or false',
          Icons.help_outline,
          const Color(0xFFFF6B4D),
          () => _navigateToTrueFalse(context),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          'Remember your cards',
          Icons.psychology,
          Colors.orange,
          () => _navigateToMemoryGame(context),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          'Jumble your cards',
          Icons.text_fields,
          const Color(0xFFFF6B4D),
          () => _navigateToWordScramble(context),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          'Write your card',
          Icons.edit,
          Colors.blue,
          () => _navigateToWriting(context),
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          'Shuffle Your Cards',
          Icons.shuffle,
          Colors.purple,
          () => _navigateToShuffleCards(context),
        ),
      ],
    );
  }





  Widget _buildMenuButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
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
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
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
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
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
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.study,
        ),
      ),
    );
  }

  void _navigateToTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.test,
        ),
      ),
    );
  }

  void _navigateToTrueFalse(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.trueFalse,
        ),
      ),
    );
  }

  void _navigateToWriting(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.write,
        ),
      ),
    );
  }

  void _navigateToMemoryGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.game,
        ),
      ),
    );
  }

  void _navigateToWordScramble(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyTypeSelectionView(
          gameMode: GameMode.bubbleWord,
        ),
      ),
    );
  }

  void _navigateToShuffleCards(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ShuffleCardsView(),
      ),
    );
  }





  void _addSampleData(BuildContext context) async {
    final provider = context.read<FlashcardProvider>();
    await SampleDataService.addSampleData(provider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample Dutch vocabulary added!')),
    );
  }
}