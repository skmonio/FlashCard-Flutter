import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/flashcard_provider.dart';

import '../components/main_header.dart';
import '../components/game_guide_dialog.dart';
import '../models/flash_card.dart';
import '../models/deck.dart';
import '../models/study_config.dart';

import 'advanced_study_view.dart';
import 'multiple_choice_view.dart';
import 'true_false_view.dart';
import 'writing_view.dart';
import 'memory_game_view.dart';
import 'pick_your_card_view.dart';
import 'pop_your_card_view.dart';
import 'connect_cards_view.dart';
import 'word_scramble_view.dart';
import 'sentence_building_view.dart';
import 'de_het_view.dart';
import 'so_many_cards_view.dart';
import 'time_your_cards_view.dart';
import '../models/timed_difficulty.dart';

enum GameMode {
  study,
  test,
  trueFalse,
  write,
  game,
  wordScramble,
  pickYourCard,
  popYourCard,
  connectCards,
  sentenceBuilding,
  deHet,
  soManyCards,
  timeYourCards,
}

class StudyTypeSelectionView extends StatefulWidget {
  final GameMode gameMode;
  final String? initialDeckId;

  const StudyTypeSelectionView({
    super.key,
    required this.gameMode,
    this.initialDeckId,
  });

  @override
  State<StudyTypeSelectionView> createState() => _StudyTypeSelectionViewState();
}

class _StudyTypeSelectionViewState extends State<StudyTypeSelectionView> {
  int _selectedCardCount = 10;
  bool _startFlipped = false;
  bool _autoProgress = false;
  bool _useLivesMode = false;
  int _selectedLives = 2; // Default to medium difficulty

  // New settings for flipped mode
  String _flippedMode = 'normal'; // 'normal', 'flipped'

  // Timed mode settings
  bool _useTimedMode = false;
  TimedDifficulty _selectedTimedDifficulty = TimedDifficulty.medium;

  // SRS settings
  bool _useSRSFiltering = true; // Default to SRS on

  // Deck selection
  Set<String> _selectedDeckIds = {}; // Empty means "Any" (all decks)
  bool _useAllCardsForAnswers = false;
  bool _oneAnswerMode = false;
  bool _enableHints = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDeckId != null) {
      _selectedDeckIds = {widget.initialDeckId!};
    }
    final provider = context.read<FlashcardProvider>();
    provider.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GameGuideDialog.showIfFirstTime(context, widget.gameMode);
    });

    // Set default flipped mode to 'flipped' for sentence building (Build Dutch from English)
    if (widget.gameMode == GameMode.sentenceBuilding) {
      _flippedMode = 'flipped';
    }

    _loadSavedSettings();
  }

  @override
  void dispose() {
    // Remove listener when disposing
    final provider = context.read<FlashcardProvider>();
    provider.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    // Only rebuild if actually needed - provider debouncing handles most updates
    // This view doesn't need to rebuild on every provider change
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedCardCount = prefs.getInt('study_card_count') ?? 10;
      _startFlipped = prefs.getBool('study_start_flipped') ?? false;
      _autoProgress = prefs.getBool('study_auto_progress') ?? false;
      _useLivesMode = prefs.getBool('study_lives_mode') ?? false;
      _selectedLives = prefs.getInt('study_lives') ?? 2;
      _flippedMode = prefs.getString('study_flipped_mode') ??
          (widget.gameMode == GameMode.sentenceBuilding ? 'flipped' : 'normal');
      _useTimedMode = prefs.getBool('study_timed_mode') ?? false;
      _selectedTimedDifficulty = TimedDifficulty.values[
          prefs.getInt('study_timed_difficulty') ?? TimedDifficulty.medium.index];
      _useSRSFiltering = prefs.getBool('study_srs_filtering') ?? true;
      _useAllCardsForAnswers = prefs.getBool('study_all_cards_answers') ?? false;
      _oneAnswerMode = prefs.getBool('study_one_answer_mode') ?? false;
      _enableHints = prefs.getBool('study_enable_hints') ?? true;
    });
  }

  Future<void> _saveAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('study_card_count', _selectedCardCount);
    await prefs.setBool('study_start_flipped', _startFlipped);
    await prefs.setBool('study_auto_progress', _autoProgress);
    await prefs.setBool('study_lives_mode', _useLivesMode);
    await prefs.setInt('study_lives', _selectedLives);
    await prefs.setString('study_flipped_mode', _flippedMode);
    await prefs.setBool('study_timed_mode', _useTimedMode);
    await prefs.setInt('study_timed_difficulty', _selectedTimedDifficulty.index);
    await prefs.setBool('study_srs_filtering', _useSRSFiltering);
    await prefs.setBool('study_all_cards_answers', _useAllCardsForAnswers);
    await prefs.setBool('study_one_answer_mode', _oneAnswerMode);
    await prefs.setBool('study_enable_hints', _enableHints);
  }

  Future<void> _resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('study_card_count');
    await prefs.remove('study_start_flipped');
    await prefs.remove('study_auto_progress');
    await prefs.remove('study_lives_mode');
    await prefs.remove('study_lives');
    await prefs.remove('study_flipped_mode');
    await prefs.remove('study_timed_mode');
    await prefs.remove('study_timed_difficulty');
    await prefs.remove('study_srs_filtering');
    await prefs.remove('study_all_cards_answers');
    await prefs.remove('study_one_answer_mode');
    await prefs.remove('study_enable_hints');
    if (!mounted) return;
    setState(() {
      _selectedCardCount = 10;
      _startFlipped = false;
      _autoProgress = false;
      _useLivesMode = false;
      _selectedLives = 2;
      _flippedMode = widget.gameMode == GameMode.sentenceBuilding ? 'flipped' : 'normal';
      _useTimedMode = false;
      _selectedTimedDifficulty = TimedDifficulty.medium;
      _useSRSFiltering = true;
      _useAllCardsForAnswers = false;
      _oneAnswerMode = false;
      _enableHints = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          MainHeader(
            title: _getGameModeTitle(),
            leftAction: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => Navigator.of(context).pop(),
            ),
            rightAction: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.help_outline,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    size: 22,
                  ),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  tooltip: 'How to Play',
                  onPressed: () =>
                      GameGuideDialog.show(context, widget.gameMode),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.play_arrow,
                    color: Colors.green,
                    size: 28,
                  ),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onPressed: _startStudy,
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Deck Selection
                  _buildDeckSelection(),
                  const SizedBox(height: 24),

                  // Study Options
                  _buildStudyOptions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowSettings() {
    // All game modes now have settings
    return true;
  }

  bool _getStartFlipped() {
    if (_shouldShowSettings()) {
      return _flippedMode == 'flipped';
    }
    return _startFlipped;
  }

  int? _getTimePerQuestion() {
    if (!_useTimedMode) return null;

    switch (_selectedTimedDifficulty) {
      case TimedDifficulty.easy:
        return 30; // 30 seconds per question
      case TimedDifficulty.medium:
        return 20; // 20 seconds per question
      case TimedDifficulty.hard:
        return 15; // 15 seconds per question
    }
  }

  Widget _buildDeckSelection() {
    final provider = context.read<FlashcardProvider>();

    // Get selected deck names for display
    String selectedDecksText;
    if (_selectedDeckIds.isEmpty) {
      selectedDecksText = 'Any (All Decks)';
    } else if (_selectedDeckIds.length == 1) {
      final deck = provider.getDeck(_selectedDeckIds.first);
      selectedDecksText = deck?.name ?? 'Unknown Deck';
    } else {
      selectedDecksText = '${_selectedDeckIds.length} decks selected';
    }

    return Card(
      child: InkWell(
        onTap: () => _showDeckSelectionDialog(),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.folder, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select your deck(s)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedDecksText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeckSelectionDialog() {
    final provider = context.read<FlashcardProvider>();
    final allDecks = provider.getAllDecksHierarchical();

    final searchController = TextEditingController();
    String dialogSearchText = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return StatefulBuilder(
            builder: (context, setInternalState) {
              final filteredDecks = dialogSearchText.isEmpty
                  ? allDecks
                  : allDecks
                        .where(
                          (d) => d.name.toLowerCase().contains(
                            dialogSearchText.toLowerCase(),
                          ),
                        )
                        .toList();

              return AlertDialog(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Select Decks (${allDecks.length})'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search decks...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: dialogSearchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  searchController.clear();
                                  setInternalState(() {
                                    dialogSearchText = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setInternalState(() {
                          dialogSearchText = value;
                        });
                      },
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "Any" option (only show if not searching)
                        if (dialogSearchText.isEmpty)
                          _buildDeckOption(
                            'Any (All Decks)',
                            'Use cards from all available decks',
                            _selectedDeckIds.isEmpty,
                            () {
                              setInternalState(() {
                                _selectedDeckIds.clear();
                              });
                              setState(() {
                                _selectedDeckIds.clear();
                              });
                              Navigator.of(context).pop();
                            },
                          ),

                        if (dialogSearchText.isEmpty) const SizedBox(height: 8),

                        // Individual deck options
                        if (filteredDecks.isNotEmpty) ...[
                          if (dialogSearchText.isEmpty) const Divider(),
                          if (dialogSearchText.isEmpty)
                            const SizedBox(height: 8),
                          ...filteredDecks.map(
                            (deck) => _buildDeckOption(
                              deck.name,
                              '${provider.getCardsForDeckWithSubDecks(deck.id).length} cards',
                              _selectedDeckIds.contains(deck.id),
                              () {
                                setInternalState(() {
                                  if (_selectedDeckIds.contains(deck.id)) {
                                    _selectedDeckIds.remove(deck.id);
                                  } else {
                                    _selectedDeckIds.add(deck.id);
                                  }
                                });
                                setState(() {
                                  // Update the main widget state to reflect the changes
                                });
                              },
                            ),
                          ),
                        ] else if (dialogSearchText.isNotEmpty) ...[
                          const SizedBox(height: 32),
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No decks found matching "$dialogSearchText"',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setInternalState(() {
                        _selectedDeckIds.clear();
                      });
                      setState(() {
                        _selectedDeckIds.clear();
                      });
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  bool _shouldShowAnswerPoolToggle() {
    // Only show answer pool for test-like modes where wrong options are generated
    return widget.gameMode != GameMode.study &&
        widget.gameMode != GameMode.write &&
        widget.gameMode != GameMode.popYourCard &&
        widget.gameMode != GameMode.connectCards &&
        widget.gameMode != GameMode.wordScramble &&
        widget.gameMode != GameMode.pickYourCard &&
        widget.gameMode != GameMode.sentenceBuilding &&
        widget.gameMode != GameMode.deHet &&
        widget.gameMode != GameMode.soManyCards &&
        widget.gameMode != GameMode.timeYourCards;
  }

  Widget _buildDeckOption(
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Study Options',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card count selector (always shown)
            _buildCardCountSelector(),
            const SizedBox(height: 16),

            // SRS filtering toggle (always shown)
            _buildSRSToggle(),
            const SizedBox(height: 16),

            // Start flipped toggle (only for study, test, true/false modes)
            if (_shouldShowFlippedMode()) ...[
              _buildStartFlippedToggle(),
              const SizedBox(height: 16),
            ],

            if (_shouldShowAnswerPoolToggle()) ...[
              _buildAnswerPoolToggle(),
              const SizedBox(height: 16),
            ],

            // Auto progress toggle (only for applicable modes)
            if (_shouldShowAutoProgress()) ...[
              _buildAutoProgressToggle(),
              const SizedBox(height: 16),
            ],

            // Lives mode toggle (only for applicable modes)
            if (_shouldShowLivesMode()) ...[
              _buildLivesModeToggle(),
              if (_useLivesMode) ...[
                const SizedBox(height: 12),
                _buildLivesSelector(),
              ],
              const SizedBox(height: 16),
            ],

            // Timed mode toggle (only for applicable modes)
            if (_shouldShowTimedMode()) ...[
              _buildTimedModeToggle(),
              if (_useTimedMode) ...[
                const SizedBox(height: 12),
                _buildTimedDifficultySelector(),
              ],
              const SizedBox(height: 16),
            ],

            // 1 Answer Mode toggle (only for applicable modes)
            if (_shouldShowOneAnswerMode()) ...[
              _buildOneAnswerModeToggle(),
              const SizedBox(height: 16),
            ],
            if (_shouldShowHintsToggle()) ...[
              _buildHintsToggle(),
              const SizedBox(height: 16),
            ],

            // Reset to defaults button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetToDefaults,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset to defaults'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOneAnswerModeToggle([StateSetter? setState]) {
    return Row(
      children: [
        const Icon(Icons.touch_app, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1 Click Answer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                _oneAnswerMode
                    ? 'Only one attempt per question'
                    : 'Many attempts per question',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _oneAnswerMode,
          onChanged: (value) {
            if (setState != null) {
              setState(() {
                _oneAnswerMode = value;

                if ((_useTimedMode || _useLivesMode) && _oneAnswerMode) {
                  _enableHints = false;
                }
              });
            }
            this.setState(() {
              _oneAnswerMode = value;

              if ((_useTimedMode || _useLivesMode) && _oneAnswerMode) {
                _enableHints = false;
              }
            });
            _saveAllSettings();
          },
        ),
      ],
    );
  }

  Widget _buildHintsToggle([StateSetter? setState]) {
    final bool isForcedOffForDifficulty =
        (_useTimedMode || _useLivesMode) && _oneAnswerMode;

    return Row(
      children: [
        Icon(
          Icons.lightbulb_outline,
          size: 20,
          color: isForcedOffForDifficulty ? Colors.grey : Colors.orange,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enable Hints',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isForcedOffForDifficulty
                      ? Theme.of(context).disabledColor
                      : null,
                ),
              ),
              Text(
                isForcedOffForDifficulty
                    ? 'Hints disabled in Timed/Lives & 1-Answer mode'
                    : (_enableHints
                          ? 'Hints are enabled during play'
                          : 'No hints allowed during play'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: isForcedOffForDifficulty ? false : _enableHints,
          onChanged: isForcedOffForDifficulty
              ? null
              : (value) {
                  if (setState != null) {
                    setState(() {
                      _enableHints = value;
                    });
                  }
                  this.setState(() {
                    _enableHints = value;
                  });
                  _saveAllSettings();
                },
        ),
      ],
    );
  }

  Widget _buildSRSToggle() {
    return Row(
      children: [
        const Icon(Icons.psychology, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SRS Filtering',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Prioritize cards due for review',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _useSRSFiltering,
          onChanged: (value) {
            setState(() {
              _useSRSFiltering = value;
            });
            _saveAllSettings();
          },
        ),
      ],
    );
  }

  Widget _buildStartFlippedToggle() {
    return Row(
      children: [
        const Icon(Icons.flip, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Start Flipped',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Show translations first',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _flippedMode == 'flipped',
          onChanged: (value) {
            setState(() {
              _flippedMode = value ? 'flipped' : 'normal';
            });
            _saveAllSettings();
          },
        ),
      ],
    );
  }

  Widget _buildAutoProgressToggle() {
    return Row(
      children: [
        const Icon(Icons.play_arrow, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto Progress',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Automatically advance to next card',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _autoProgress,
          onChanged: (value) {
            setState(() {
              _autoProgress = value;
            });
            _saveAllSettings();
          },
        ),
      ],
    );
  }

  Widget _buildLivesModeToggle() {
    return Row(
      children: [
        const Icon(Icons.favorite, size: 20, color: Colors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lives Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Limited attempts per card',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _useLivesMode,
          onChanged: _useTimedMode
              ? null
              : (value) {
                  setState(() {
                    _useLivesMode = value;
                    if (!value) {
                      _selectedLives = 2; // Reset to default
                    }
                    // Disable timed mode if lives mode is enabled
                    if (value) {
                      _useTimedMode = false;
                    }
                    // Force hints off in Timed/Lives & 1 Answer mode
                    if ((_useTimedMode || _useLivesMode) && _oneAnswerMode) {
                      _enableHints = false;
                    }
                  });
                  _saveAllSettings();
                },
        ),
      ],
    );
  }

  Widget _buildLivesSelector() {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Difficulty:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDifficultyButton('Easy', 3, Colors.green)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDifficultyButton('Medium', 2, Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildDifficultyButton('Hard', 1, Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimedModeToggle() {
    return Row(
      children: [
        const Icon(Icons.timer, size: 20, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Timed Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                'Add time pressure to questions',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _useTimedMode,
          onChanged: _useLivesMode
              ? null
              : (value) {
                  setState(() {
                    _useTimedMode = value;
                    if (value) {
                      // When timed mode is enabled, disable auto progress
                      _autoProgress = false;
                    }
                    if (!value) {
                      _selectedTimedDifficulty =
                          TimedDifficulty.medium; // Reset to default
                    }
                    // Force hints off in Timed/Lives & 1 Answer mode
                    if ((_useTimedMode || _useLivesMode) && _oneAnswerMode) {
                      _enableHints = false;
                    }
                  });
                  _saveAllSettings();
                },
        ),
      ],
    );
  }

  Widget _buildTimedDifficultySelector() {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Difficulty:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimedDifficultyButton(
                  'Easy',
                  TimedDifficulty.easy,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimedDifficultyButton(
                  'Medium',
                  TimedDifficulty.medium,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimedDifficultyButton(
                  'Hard',
                  TimedDifficulty.hard,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    int lives,
    Color color, [
    StateSetter? setState,
  ]) {
    final isSelected = _selectedLives == lives;
    return GestureDetector(
      onTap: () {
        if (setState != null) {
          setState(() {
            _selectedLives = lives;
          });
        }
        this.setState(() {
          _selectedLives = lives;
        });
        _saveAllSettings();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '$label ($lives)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTimedDifficultyButton(
    String label,
    TimedDifficulty difficulty,
    Color color, [
    StateSetter? setState,
  ]) {
    final isSelected = _selectedTimedDifficulty == difficulty;
    String timeText;
    switch (difficulty) {
      case TimedDifficulty.easy:
        timeText = '7s';
        break;
      case TimedDifficulty.medium:
        timeText = '5s';
        break;
      case TimedDifficulty.hard:
        timeText = '3s';
        break;
    }

    return GestureDetector(
      onTap: () {
        if (setState != null) {
          setState(() {
            _selectedTimedDifficulty = difficulty;
          });
        }
        this.setState(() {
          _selectedTimedDifficulty = difficulty;
        });
        _saveAllSettings();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          '$label ($timeText)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildStudyTypeCard(
    String title,
    String subtitle,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_list_numbered, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Number of Cards',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _selectedCardCount.toDouble(),
                min: 5,
                max: 50,
                divisions: 9,
                label: '$_selectedCardCount',
                onChanged: (value) {
                  setState(() {
                    _selectedCardCount = value.round();
                  });
                  _saveAllSettings();
                },
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$_selectedCardCount',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  void _startStudy() {
    final provider = context.read<FlashcardProvider>();

    // Check if provider is still loading data
    if (provider.isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading your cards, please wait a moment...'),
        ),
      );
      return;
    }

    // Get cards based on deck selection
    List<FlashCard> allSelectedCards = [];
    Set<String> seenCardIds = {};

    if (_selectedDeckIds.isEmpty) {
      // Use all cards (Any deck option)
      allSelectedCards = provider.cards;
    } else {
      // Use selected decks
      for (final deckId in _selectedDeckIds) {
        final deck = provider.getDeck(deckId);
        if (deck != null) {
          final deckCards = provider.getCardsForDeckWithSubDecks(deck.id);
          for (final card in deckCards) {
            if (!seenCardIds.contains(card.id)) {
              allSelectedCards.add(card);
              seenCardIds.add(card.id);
            }
          }
        }
      }
    }

    if (allSelectedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available in selected decks.')),
      );
      return;
    }

    // Prepare lists for filtering and warnings
    final availableCards = allSelectedCards
        .where((card) => card.canBeStudiedToday)
        .toList();
    final limitedCards = allSelectedCards
        .where((card) => card.hasReachedDailyLimit)
        .toList();

    // Apply SRS filtering if enabled
    List<FlashCard> filteredCards;
    if (_useSRSFiltering) {
      // Sort by due status: due cards first, then not due
      // Only include cards that can be studied today (have HP > 0)
      final dueCards = availableCards
          .where((card) => card.isDueForReview)
          .toList();
      final potentiallyDueCards = availableCards
          .where((card) => !card.isDueForReview)
          .toList();
      filteredCards = [...dueCards, ...potentiallyDueCards];

      if (filteredCards.isEmpty) {
        if (limitedCards.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No cards currently due for SRS study. Your cards need some rest!',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No cards are currently due for review based on SRS.',
              ),
            ),
          );
        }
        return;
      }
    } else {
      // Show all cards regardless of SRS status
      // But we still prioritize those that can be studied today
      final defeatedCards = allSelectedCards
          .where((card) => !card.canBeStudiedToday)
          .toList();

      if (availableCards.isNotEmpty) {
        filteredCards = [...availableCards, ...defeatedCards];
      } else {
        // If ALL are defeated, we still let them play if SRS is off, but show a warning
        filteredCards = allSelectedCards;
      }
    }

    // 🔍 Special filtering for Sentence Your Cards
    if (widget.gameMode == GameMode.sentenceBuilding) {
      filteredCards = filteredCards
          .where((card) => card.example.isNotEmpty)
          .toList();
    }

    // 🔍 Special filtering for De of Het — only cards with article
    if (widget.gameMode == GameMode.deHet) {
      filteredCards = filteredCards
          .where((card) => card.article == 'de' || card.article == 'het')
          .toList();
      if (filteredCards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'None of your cards have an article (de/het) set. Open a card and add the article to play this game.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // Check if we have enough cards to play
    if (filteredCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No cards available in the selected pool.'),
        ),
      );
      return;
    }

    // Shuffle and take a subset of cards
    final shuffledCards = List<FlashCard>.from(filteredCards)..shuffle();
    final desiredCount = _selectedCardCount >= 50
        ? filteredCards.length
        : _selectedCardCount;
    final clampedCount = desiredCount.clamp(1, filteredCards.length);
    final cardCount = clampedCount is int ? clampedCount : clampedCount.toInt();
    final studyCards = shuffledCards.take(cardCount).toList();

    // Only show warning if defeated cards would have been in the study set
    // OR if almost all cards are defeated (making it hard to create games)
    final totalCardsInPool = filteredCards.length + limitedCards.length;
    final defeatedRatio = totalCardsInPool > 0
        ? limitedCards.length / totalCardsInPool
        : 0.0;

    // Check if any defeated cards would have been selected (if we had more cards available)
    // This happens when the user requests more cards than are available due to defeated cards
    final requestedCount = _selectedCardCount >= 50
        ? availableCards.length
        : _selectedCardCount;
    final wouldHaveIncludedDefeated =
        requestedCount > availableCards.length && limitedCards.isNotEmpty;

    // Show warning only if:
    // 1. Defeated cards would have been in the study set, OR
    // 2. More than 80% of cards are defeated (making it hard to create games)
    if ((wouldHaveIncludedDefeated || defeatedRatio > 0.8) &&
        limitedCards.isNotEmpty &&
        availableCards.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${limitedCards.length} cards are defeated (0 HP). They need to rest until tomorrow to regain health.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // Create study config
    final studyConfig = StudyConfig(
      deckIds: _selectedDeckIds.toList(),
      deckNames: _selectedDeckIds.isEmpty
          ? ['All Decks']
          : _selectedDeckIds
                .map((id) => provider.getDeck(id)?.name ?? 'Unknown')
                .toList(),
      cardCount: studyCards.length,
      useSRSFiltering: _useSRSFiltering,
      startFlipped: _getStartFlipped(),
      autoProgress: _autoProgress,
      useLivesMode: _useLivesMode,
      customLives: _useLivesMode ? _selectedLives : null,
      useTimedMode: _useTimedMode,
      timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
      timePerQuestion: _getTimePerQuestion(),
      useAllCardsForAnswers: _useAllCardsForAnswers,
      oneAnswerMode: _oneAnswerMode,
      enableHints: _enableHints,
    );

    final answerPoolCards = _useAllCardsForAnswers
        ? provider.cards
        : allSelectedCards;

    // Navigate based on game mode
    switch (widget.gameMode) {
      case GameMode.study:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdvancedStudyView(
              cards: studyCards,
              startFlipped: _getStartFlipped(),
              title: 'Study',
              studyConfig: studyConfig,
            ),
          ),
        );
        break;
      case GameMode.test:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultipleChoiceView(
              cards: studyCards,
              title: _useTimedMode ? 'Timed Test' : 'Test Mode',
              autoProgress: _autoProgress,
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
              startFlipped: _getStartFlipped(),
              studyConfig: studyConfig,
              answerPoolCards: answerPoolCards,
              oneAnswerMode: _oneAnswerMode,
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.trueFalse:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrueFalseView(
              cards: studyCards,
              title: _useTimedMode ? 'Timed True/False' : 'True/False',
              autoProgress: _autoProgress,
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
              startFlipped: _getStartFlipped(),
              studyConfig: studyConfig,
              answerPoolCards: answerPoolCards,
              oneAnswerMode: _oneAnswerMode,
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.write:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WritingView(
              cards: studyCards,
              title: 'Writing Practice',
              autoProgress: _autoProgress,
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              startFlipped: _getStartFlipped(),
              useTimedMode: _useTimedMode,
              timePerQuestion: _getTimePerQuestion(),
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.game:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MemoryGameView(cards: studyCards),
          ),
        );
        break;
      case GameMode.wordScramble:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WordScrambleView(
              cards: studyCards,
              title: _useTimedMode ? 'Timed Jumble' : 'Jumble',
              autoProgress: _autoProgress,
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
              startFlipped: _getStartFlipped(),
              oneAnswerMode: _oneAnswerMode,
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.pickYourCard:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PickYourCardView(
              cards: studyCards,
              title: 'Pick Your Card',
              oneAnswerMode: _oneAnswerMode,
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.popYourCard:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PopYourCardView(
              cards: studyCards,
              title: 'Pop Your Card',
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timePerQuestion: _useTimedMode ? _getTimePerQuestion() : null,
              oneAnswerMode: _oneAnswerMode,
            ),
          ),
        );
        break;
      case GameMode.connectCards:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ConnectCardsView(
              cards: studyCards,
              title: 'Connect Cards',
              autoProgress: _autoProgress,
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timePerQuestion: _useTimedMode ? _getTimePerQuestion() : null,
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.sentenceBuilding:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SentenceBuildingView(
              cards: studyCards,
              title: 'Sentence Your Cards',
              autoProgress: _autoProgress,
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              startFlipped: _getStartFlipped(),
              oneAnswerMode: _oneAnswerMode,
              enableHints: _enableHints,
            ),
          ),
        );
        break;
      case GameMode.deHet:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeHetView(
              cards: studyCards,
              title: 'De of Het',
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
              studyConfig: studyConfig,
            ),
          ),
        );
        break;
      case GameMode.soManyCards:
        final cardsWithPlurals = studyCards
            .where((c) => c.plural.isNotEmpty)
            .toList();
        if (cardsWithPlurals.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cards with plurals.')),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SoManyCardsView(
              cards: cardsWithPlurals,
              title: 'So Many Cards',
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
              studyConfig: studyConfig,
            ),
          ),
        );
        break;
      case GameMode.timeYourCards:
        final verbCards = studyCards
            .where(
              (c) =>
                  c.presentTense.isNotEmpty ||
                  c.pastTense.isNotEmpty ||
                  c.perfectTense.isNotEmpty,
            )
            .toList();
        if (verbCards.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cards with verb forms found in selection.'),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TimeYourCardsView(
              cards: verbCards,
              title: 'Time Your Cards',
              useLivesMode: _useLivesMode,
              customLives: _useLivesMode ? _selectedLives : null,
              useTimedMode: _useTimedMode,
              timedDifficulty: _useTimedMode ? _selectedTimedDifficulty : null,
              studyConfig: studyConfig,
            ),
          ),
        );
        break;
    }
  }

  // Old navigation methods removed - now using _startStudy()

  List<Deck> _sortDecksHierarchically(
    List<Deck> decks,
    FlashcardProvider provider,
  ) {
    // Separate parent and child decks
    final parentDecks = decks.where((deck) => deck.parentId == null).toList();
    final childDecks = decks.where((deck) => deck.parentId != null).toList();

    // Sort parent decks A-Z
    parentDecks.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    // Sort child decks within each parent
    childDecks.sort((a, b) {
      // First sort by parent deck name
      final parentA = provider.getDeck(a.parentId!);
      final parentB = provider.getDeck(b.parentId!);

      if (parentA != null && parentB != null) {
        final parentComparison = parentA.name.toLowerCase().compareTo(
          parentB.name.toLowerCase(),
        );

        if (parentComparison != 0) {
          return parentComparison;
        }
      }

      // Then sort by child deck name A-Z
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Combine parent and child decks in hierarchical order
    final result = <Deck>[];

    // Add parent decks and their children in hierarchical order
    for (final parentDeck in parentDecks) {
      // Add the parent deck
      result.add(parentDeck);

      // Add all children of this parent deck immediately after
      final children = childDecks
          .where((child) => child.parentId == parentDeck.id)
          .toList();
      result.addAll(children);
    }

    return result;
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${_getGameModeTitle()} Settings'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flipped Mode (for study, test, true/false modes)
                if (_shouldShowFlippedMode()) ...[
                  _buildFlippedModeSetting(setState),
                  const SizedBox(height: 16),
                ],

                // Auto Progress (for test, true/false, jumble modes)
                if (_shouldShowAutoProgress()) ...[
                  _buildAutoProgressSetting(setState),
                  const SizedBox(height: 16),
                ],

                // Lives Mode (for test, true/false, jumble modes)
                if (_shouldShowLivesMode()) ...[
                  _buildLivesModeSetting(setState),
                  const SizedBox(height: 16),
                ],

                // Timed Mode (for test, true/false, jumble modes)
                if (_shouldShowTimedMode()) ...[
                  _buildTimedModeSetting(setState),
                  const SizedBox(height: 16),
                ],

                // Number of Cards (for all modes)
                _buildCardCountSetting(setState),
                const SizedBox(height: 16),

                // SRS Filtering (for all modes)
                _buildSRSFilteringSetting(setState),
                const SizedBox(height: 16),

                // One Answer Mode (for applicable modes)
                if (_shouldShowOneAnswerMode()) ...[
                  _buildOneAnswerModeToggle(setState),
                  const SizedBox(height: 16),
                ],

                // Hints Toggle (for applicable modes)
                if (_shouldShowHintsToggle()) ...[
                  _buildHintsToggle(setState),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  String _getGameModeTitle() {
    switch (widget.gameMode) {
      case GameMode.study:
        return 'Study';
      case GameMode.test:
        return 'Test';
      case GameMode.trueFalse:
        return 'True/False';
      case GameMode.write:
        return 'Write';
      case GameMode.game:
        return 'Remember';
      case GameMode.wordScramble:
        return 'Jumble';
      case GameMode.pickYourCard:
        return 'Pick';
      case GameMode.popYourCard:
        return 'Pop';
      case GameMode.connectCards:
        return 'Connect';
      case GameMode.sentenceBuilding:
        return 'Sentence';
      case GameMode.deHet:
        return 'De of Het';
      case GameMode.soManyCards:
        return 'So Many Cards';
      case GameMode.timeYourCards:
        return 'Time Your Cards';
      default:
        return 'Study';
    }
  }

  bool _shouldShowFlippedMode() {
    return widget.gameMode == GameMode.study ||
        widget.gameMode == GameMode.test ||
        widget.gameMode == GameMode.trueFalse ||
        widget.gameMode == GameMode.sentenceBuilding ||
        widget.gameMode == GameMode.soManyCards ||
        widget.gameMode == GameMode.timeYourCards;
  }

  bool _shouldShowAutoProgress() {
    return widget.gameMode == GameMode.test ||
        widget.gameMode == GameMode.trueFalse ||
        widget.gameMode == GameMode.wordScramble ||
        widget.gameMode == GameMode.pickYourCard ||
        widget.gameMode == GameMode.write ||
        widget.gameMode == GameMode.connectCards ||
        widget.gameMode == GameMode.soManyCards ||
        widget.gameMode == GameMode.timeYourCards;
  }

  bool _shouldShowLivesMode() {
    return widget.gameMode == GameMode.test ||
        widget.gameMode == GameMode.trueFalse ||
        widget.gameMode == GameMode.wordScramble ||
        widget.gameMode == GameMode.pickYourCard ||
        widget.gameMode == GameMode.popYourCard ||
        widget.gameMode == GameMode.write ||
        widget.gameMode == GameMode.connectCards ||
        widget.gameMode == GameMode.deHet ||
        widget.gameMode == GameMode.sentenceBuilding ||
        widget.gameMode == GameMode.soManyCards ||
        widget.gameMode == GameMode.timeYourCards;
  }

  bool _shouldShowTimedMode() {
    return widget.gameMode == GameMode.test ||
        widget.gameMode == GameMode.trueFalse ||
        widget.gameMode == GameMode.wordScramble ||
        widget.gameMode == GameMode.pickYourCard ||
        widget.gameMode == GameMode.popYourCard ||
        widget.gameMode == GameMode.write ||
        widget.gameMode == GameMode.connectCards ||
        widget.gameMode == GameMode.deHet ||
        widget.gameMode == GameMode.sentenceBuilding ||
        widget.gameMode == GameMode.soManyCards ||
        widget.gameMode == GameMode.timeYourCards;
  }

  bool _shouldShowOneAnswerMode() {
    return widget.gameMode == GameMode.test ||
        widget.gameMode == GameMode.pickYourCard ||
        widget.gameMode == GameMode.popYourCard ||
        widget.gameMode == GameMode.wordScramble ||
        widget.gameMode == GameMode.write ||
        widget.gameMode == GameMode.connectCards ||
        widget.gameMode == GameMode.sentenceBuilding ||
        widget.gameMode == GameMode.timeYourCards;
  }

  bool _shouldShowHintsToggle() {
    return widget.gameMode == GameMode.test ||
        widget.gameMode == GameMode.wordScramble ||
        widget.gameMode == GameMode.connectCards ||
        widget.gameMode == GameMode.write ||
        widget.gameMode == GameMode.pickYourCard ||
        widget.gameMode == GameMode.sentenceBuilding;
  }

  Widget _buildFlippedModeSetting(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Card Display Mode',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildFlippedModeButton('Normal', 'normal', setState),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFlippedModeButton('Flipped', 'flipped', setState),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlippedModeButton(
    String label,
    String value,
    StateSetter setState,
  ) {
    final isSelected = _flippedMode == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _flippedMode = value;
        });
        this.setState(() {
          _flippedMode = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildAutoProgressSetting(StateSetter setState) {
    // Auto progress is disabled when timed mode is enabled
    final isDisabled = _useTimedMode;

    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          size: 20,
          color: isDisabled ? Colors.grey : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Auto Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDisabled ? Colors.grey : null,
            ),
          ),
        ),
        Switch(
          value: isDisabled ? true : _autoProgress,
          onChanged: isDisabled
              ? null
              : (value) {
                  setState(() {
                    _autoProgress = value;
                  });
                  this.setState(() {
                    _autoProgress = value;
                  });
                },
        ),
      ],
    );
  }

  Widget _buildLivesModeSetting(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, size: 20, color: Colors.red),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Lives Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: _useLivesMode,
              onChanged: _useTimedMode
                  ? null
                  : (value) {
                      setState(() {
                        _useLivesMode = value;
                        if (!value) {
                          _selectedLives = 2; // Reset to default
                        }
                        // Disable timed mode if lives mode is enabled
                        if (value) {
                          _useTimedMode = false;
                        }
                      });
                      this.setState(() {
                        _useLivesMode = value;
                        if (!value) {
                          _selectedLives = 2; // Reset to default
                        }
                        // Disable timed mode if lives mode is enabled
                        if (value) {
                          _useTimedMode = false;
                        }
                      });
                    },
            ),
          ],
        ),
        if (_useLivesMode) ...[
          const SizedBox(height: 16),
          const Text(
            'Select Difficulty:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDifficultyButton(
                  'Easy',
                  3,
                  Colors.green,
                  setState,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDifficultyButton(
                  'Medium',
                  2,
                  Colors.orange,
                  setState,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDifficultyButton('Hard', 1, Colors.red, setState),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimedModeSetting(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.timer, size: 20, color: Colors.blue),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Timed Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: _useTimedMode,
              onChanged: _useLivesMode
                  ? null
                  : (value) {
                      setState(() {
                        _useTimedMode = value;
                        if (value) {
                          // When timed mode is enabled, enable auto progress
                          _autoProgress = true;
                        }
                        if (!value) {
                          _selectedTimedDifficulty =
                              TimedDifficulty.medium; // Reset to default
                        }
                      });
                      this.setState(() {
                        _useTimedMode = value;
                        if (value) {
                          // When timed mode is enabled, enable auto progress
                          _autoProgress = true;
                        }
                        if (!value) {
                          _selectedTimedDifficulty =
                              TimedDifficulty.medium; // Reset to default
                        }
                      });
                    },
            ),
          ],
        ),
        if (_useTimedMode) ...[
          const SizedBox(height: 16),
          const Text(
            'Select Difficulty:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTimedDifficultyButton(
                  'Easy',
                  TimedDifficulty.easy,
                  Colors.green,
                  setState,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimedDifficultyButton(
                  'Medium',
                  TimedDifficulty.medium,
                  Colors.orange,
                  setState,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimedDifficultyButton(
                  'Hard',
                  TimedDifficulty.hard,
                  Colors.red,
                  setState,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCardCountSetting(StateSetter setState) {
    final isInfinite = _selectedCardCount >= 50;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_list_numbered, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Number of Cards',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              isInfinite ? 'All' : '$_selectedCardCount',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: isInfinite ? 50.0 : _selectedCardCount.toDouble(),
          min: 5,
          max: 50,
          divisions: 9,
          label: isInfinite ? 'All' : '$_selectedCardCount',
          onChanged: (value) {
            setState(() {
              _selectedCardCount = value.round();
            });
            this.setState(() {
              _selectedCardCount = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildSRSFilteringSetting(StateSetter setState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SRS Filtering',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Switch(
              value: _useSRSFiltering,
              onChanged: (value) {
                setState(() {
                  _useSRSFiltering = value;
                });
                this.setState(() {
                  _useSRSFiltering = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _useSRSFiltering
              ? 'Show cards based on SRS schedule (due cards first)'
              : 'Show all cards regardless of SRS schedule',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  void _showGameInfo(BuildContext context) {
    String title = '';
    String content = '';

    switch (widget.gameMode) {
      case GameMode.study:
        title = 'Study Mode';
        content =
            'Practice with your flashcards using spaced repetition learning.';
        break;
      case GameMode.test:
        title = 'Test Mode';
        content =
            'Challenge yourself with multiple choice questions to assess your knowledge.';
        break;
      case GameMode.trueFalse:
        title = 'True or False Mode';
        content =
            'Test your knowledge with true or false questions about translations.';
        break;
      case GameMode.write:
        title = 'Write Mode';
        content = 'Practice writing translations with a hangman-style game.';
        break;
      case GameMode.game:
        title = 'Memory Game';
        content =
            'Match pairs of cards to improve your memory and recognition.';
        break;
      case GameMode.wordScramble:
        title = 'Jumble Mode';
        content =
            'Unscramble the letters to form the correct word translation.';
        break;
      case GameMode.pickYourCard:
        title = 'Pick Mode';
        content =
            'Use spinning wheels to select the correct word pieces and build the translation.';
        break;
      case GameMode.popYourCard:
        title = 'Pop Your Card Mode';
        content =
            'Tap the correct floating word bubble while avoiding the decoy variants.';
        break;
      case GameMode.connectCards:
        title = 'Connect Your Cards Mode';
        content =
            'Connect letters in a grid to spell Dutch words. Drag to connect adjacent letters and form the correct translation.';
        break;
      case GameMode.sentenceBuilding:
        title = 'Sentence Builder';
        content = 'Build full sentences by putting words in the correct order.';
        break;
      case GameMode.deHet:
        title = 'De of Het';
        content =
            'Practice Dutch articles! See a word and decide if it takes "de" or "het".';
        break;
      case GameMode.soManyCards:
        title = 'So Many Cards';
        content = 'Practice plural forms of Dutch nouns.';
        break;
      case GameMode.timeYourCards:
        title = 'Time Your Cards';
        content =
            'Practice Dutch verb tenses! Identify the correct present, past, or perfect tense for a given verb.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showTimedTestDifficultyDialog(List<FlashCard> allCards) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Difficulty'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select the difficulty level for your timed test:'),
            SizedBox(height: 16),
            Text('• Easy: 10 seconds per question'),
            Text('• Medium: 7 seconds per question'),
            Text('• Hard: 5 seconds per question'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedTest(allCards, TimedDifficulty.easy);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Easy - 10s'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedTest(allCards, TimedDifficulty.medium);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Medium - 7s'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedTest(allCards, TimedDifficulty.hard);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hard - 5s'),
          ),
        ],
      ),
    );
  }

  void _startTimedStudy(List<FlashCard> allCards, String difficulty) {
    // Shuffle and take a subset of cards
    final shuffledCards = List<FlashCard>.from(allCards)..shuffle();
    final studyCards = shuffledCards.take(_selectedCardCount).toList();

    // Use timePerQuestion (seconds per card) like other games
    final timePerQuestion = _getTimePerQuestion();

    // Navigate to memory game with timed mode
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MemoryGameView(
          cards: studyCards,
          startFlipped: _startFlipped,
          timedMode: true,
          timePerQuestion: timePerQuestion,
          difficulty: difficulty,
        ),
      ),
    );
  }

  void _startTimedTest(List<FlashCard> allCards, TimedDifficulty difficulty) {
    // Shuffle and take a subset of cards
    final shuffledCards = List<FlashCard>.from(allCards)..shuffle();
    final studyCards = shuffledCards.take(_selectedCardCount).toList();
    
    final provider = context.read<FlashcardProvider>();
    final studyConfig = StudyConfig(
      deckIds: _selectedDeckIds.toList(),
      deckNames: _selectedDeckIds.isEmpty
          ? ['All Decks']
          : _selectedDeckIds.map((id) => provider.getDeck(id)?.name ?? 'Unknown').toList(),
      cardCount: studyCards.length,
      useSRSFiltering: _useSRSFiltering,
      startFlipped: _startFlipped,
      autoProgress: _autoProgress,
      useLivesMode: _useLivesMode,
      customLives: _useLivesMode ? _selectedLives : null,
      useTimedMode: true,
      timedDifficulty: difficulty,
      timePerQuestion: difficulty == TimedDifficulty.easy ? 7 : (difficulty == TimedDifficulty.medium ? 5 : 3),
      useAllCardsForAnswers: _useAllCardsForAnswers,
      oneAnswerMode: _oneAnswerMode,
      enableHints: _enableHints,
    );

    // Navigate to timed test view using the unified MultipleChoiceView
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultipleChoiceView(
          cards: studyCards,
          title: 'Timed Test',
          useTimedMode: true,
          timedDifficulty: difficulty,
          startFlipped: _startFlipped,
          oneAnswerMode: _oneAnswerMode,
          enableHints: _enableHints,
          studyConfig: studyConfig,
          answerPoolCards: _useAllCardsForAnswers ? provider.cards : allCards,
        ),
      ),
    );
  }

  void _showTimedTrueFalseDifficultyDialog(List<FlashCard> allCards) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Difficulty'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select the difficulty level for your timed true/false test:'),
            SizedBox(height: 16),
            Text('• Easy: 7 seconds per question'),
            Text('• Medium: 5 seconds per question'),
            Text('• Hard: 3 seconds per question'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedTrueFalse(allCards, TimedDifficulty.easy);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Easy - 7s'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedTrueFalse(allCards, TimedDifficulty.medium);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Medium - 5s'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startTimedTrueFalse(allCards, TimedDifficulty.hard);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hard - 3s'),
          ),
        ],
      ),
    );
  }

  void _startTimedTrueFalse(
    List<FlashCard> allCards,
    TimedDifficulty difficulty,
  ) {
    // Shuffle and take a subset of cards
    final shuffledCards = List<FlashCard>.from(allCards)..shuffle();
    final studyCards = shuffledCards.take(_selectedCardCount).toList();
    
    final provider = context.read<FlashcardProvider>();
    final studyConfig = StudyConfig(
      deckIds: _selectedDeckIds.toList(),
      deckNames: _selectedDeckIds.isEmpty
          ? ['All Decks']
          : _selectedDeckIds.map((id) => provider.getDeck(id)?.name ?? 'Unknown').toList(),
      cardCount: studyCards.length,
      useSRSFiltering: _useSRSFiltering,
      startFlipped: _startFlipped,
      autoProgress: _autoProgress,
      useLivesMode: _useLivesMode,
      customLives: _useLivesMode ? _selectedLives : null,
      useTimedMode: true,
      timedDifficulty: difficulty,
      timePerQuestion: difficulty == TimedDifficulty.easy ? 7 : (difficulty == TimedDifficulty.medium ? 5 : 3),
      useAllCardsForAnswers: _useAllCardsForAnswers,
      oneAnswerMode: _oneAnswerMode,
      enableHints: _enableHints,
    );

    // Navigate to timed true/false view using the unified TrueFalseView
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TrueFalseView(
          cards: studyCards,
          title: 'Timed True/False',
          useTimedMode: true,
          timedDifficulty: difficulty,
          startFlipped: _startFlipped,
          oneAnswerMode: _oneAnswerMode,
          enableHints: _enableHints,
          studyConfig: studyConfig,
          answerPoolCards: _useAllCardsForAnswers ? provider.cards : allCards,
        ),
      ),
    );
  }

  Widget _buildAnswerPoolToggle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.library_books, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Answer Pool',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              Text(
                _useAllCardsForAnswers
                    ? 'Wrong answers can come from any deck'
                    : 'Wrong answers pulled only from selected deck(s)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: _useAllCardsForAnswers,
          onChanged: (value) {
            setState(() {
              _useAllCardsForAnswers = value;
            });
            _saveAllSettings();
          },
        ),
      ],
    );
  }
}

class _MultiDeckSelectionDialog extends StatefulWidget {
  final List<Deck> decks;
  final FlashcardProvider provider;
  final GameMode gameMode;
  final bool startFlipped;
  final int selectedCardCount;
  final bool autoProgress;
  final bool useLivesMode;
  final int? customLives;
  final bool useTimedMode;
  final TimedDifficulty? timedDifficulty;
  final bool useSRSFiltering;
  final bool useAllCardsForAnswers;
  final bool oneAnswerMode;

  const _MultiDeckSelectionDialog({
    required this.decks,
    required this.provider,
    required this.gameMode,
    required this.startFlipped,
    required this.selectedCardCount,
    required this.autoProgress,
    this.useLivesMode = false,
    this.customLives,
    this.useTimedMode = false,
    this.timedDifficulty,
    required this.useSRSFiltering,
    this.useAllCardsForAnswers = false,
    this.oneAnswerMode = false,
  });

  @override
  State<_MultiDeckSelectionDialog> createState() =>
      _MultiDeckSelectionDialogState();
}

class _MultiDeckSelectionDialogState extends State<_MultiDeckSelectionDialog> {
  final Set<String> _selectedDeckIds = {};
  int _totalSelectedCards = 0;
  late bool _useAllCardsForAnswers;

  @override
  void initState() {
    super.initState();
    _useAllCardsForAnswers = widget.useAllCardsForAnswers;
    _calculateTotalCards();
  }

  void _calculateTotalCards() {
    _totalSelectedCards = 0;
    for (final deckId in _selectedDeckIds) {
      final deck = widget.decks.firstWhere((d) => d.id == deckId);
      // For parent decks, include sub-deck cards; for sub-decks, only their own cards
      final deckCards = deck.isSubDeck
          ? widget.provider.getCardsForDeck(deck.id)
          : widget.provider.getCardsForDeckWithSubDecks(deck.id);
      _totalSelectedCards += deckCards.length;
    }
  }

  int? _getTimePerQuestion() {
    if (!widget.useTimedMode || widget.timedDifficulty == null) return null;

    switch (widget.timedDifficulty!) {
      case TimedDifficulty.easy:
        return 30; // 30 seconds per question
      case TimedDifficulty.medium:
        return 20; // 20 seconds per question
      case TimedDifficulty.hard:
        return 15; // 15 seconds per question
    }
  }

  StudyConfig _createStudyConfig(List<FlashCard> allSelectedCards) {
    return StudyConfig(
      deckIds: _selectedDeckIds.toList(),
      deckNames: _selectedDeckIds
          .map((id) => widget.decks.firstWhere((d) => d.id == id).name)
          .toList(),
      cardCount: widget.selectedCardCount,
      useSRSFiltering: widget.useSRSFiltering,
      startFlipped: widget.startFlipped,
      autoProgress: widget.autoProgress,
      useLivesMode: widget.useLivesMode,
      customLives: widget.customLives,
      useTimedMode: widget.useTimedMode,
      timedDifficulty: widget.timedDifficulty,
      timePerQuestion: _getTimePerQuestion(),
      useAllCardsForAnswers: _useAllCardsForAnswers,
      oneAnswerMode: widget.oneAnswerMode,
    );
  }

  void _toggleDeckSelection(String deckId) {
    setState(() {
      if (_selectedDeckIds.contains(deckId)) {
        _selectedDeckIds.remove(deckId);
      } else {
        _selectedDeckIds.add(deckId);
      }
      _calculateTotalCards();
    });
  }

  void _startStudy() {
    if (_selectedDeckIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one deck.')),
      );
      return;
    }

    // Collect all cards from selected decks with deduplication
    List<FlashCard> allSelectedCards = [];
    List<String> selectedDeckNames = [];
    Set<String> seenCardIds = {}; // Track unique card IDs

    for (final deckId in _selectedDeckIds) {
      final deck = widget.decks.firstWhere((d) => d.id == deckId);
      // For parent decks, include sub-deck cards; for sub-decks, only their own cards
      final deckCards = deck.isSubDeck
          ? widget.provider.getCardsForDeck(deck.id)
          : widget.provider.getCardsForDeckWithSubDecks(deck.id);

      // Add only unique cards (deduplicate by card ID)
      for (final card in deckCards) {
        if (!seenCardIds.contains(card.id)) {
          allSelectedCards.add(card);
          seenCardIds.add(card.id);
        }
      }
      selectedDeckNames.add(deck.name);
    }

    if (allSelectedCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards available in selected decks.')),
      );
      return;
    }

    // Apply SRS filtering if enabled
    List<FlashCard> filteredCards;
    if (widget.useSRSFiltering) {
      // Sort by due status: due cards first, then not due
      final dueCards = allSelectedCards
          .where((card) => card.isDueForReview)
          .toList();
      final notDueCards = allSelectedCards
          .where((card) => !card.isDueForReview)
          .toList();
      filteredCards = [...dueCards, ...notDueCards];
    } else {
      // Show all cards regardless of SRS status
      filteredCards = allSelectedCards;
    }

    // Apply daily study limit filtering - exclude cards that have reached their daily limit
    final availableCards = filteredCards
        .where((card) => card.canBeStudiedToday)
        .toList();
    final limitedCards = filteredCards
        .where((card) => card.hasReachedDailyLimit)
        .toList();

    // Debug logging
    print(
      '🔍 StudyTypeSelectionView: _startStudy - Total selected cards: ${allSelectedCards.length}',
    );
    print(
      '🔍 StudyTypeSelectionView: _startStudy - After SRS filtering: ${filteredCards.length}',
    );
    print(
      '🔍 StudyTypeSelectionView: _startStudy - Available cards (canBeStudiedToday): ${availableCards.length}',
    );
    print(
      '🔍 StudyTypeSelectionView: _startStudy - Limited cards (hasReachedDailyLimit): ${limitedCards.length}',
    );
    for (int i = 0; i < allSelectedCards.length && i < 5; i++) {
      final card = allSelectedCards[i];
      print(
        '🔍 StudyTypeSelectionView: Card ${i + 1}: "${card.word}" - HP: ${card.currentHP}/${card.maxHP}, canBeStudied: ${card.canBeStudiedToday}',
      );
    }

    // Use available cards for study
    filteredCards = availableCards;

    // Check if we have enough cards to play
    if (filteredCards.isEmpty) {
      final totalCards = allSelectedCards.length;
      final defeatedCards = limitedCards.length;
      final healthyCards = totalCards - defeatedCards;

      String errorMessage = 'No cards available for this game.\n\n';
      errorMessage += 'Total cards: $totalCards\n';
      errorMessage += 'Healthy cards: $healthyCards\n';
      errorMessage += 'Defeated cards: $defeatedCards\n\n';

      if (defeatedCards == totalCards) {
        errorMessage +=
            'All cards are defeated (0 HP). They need to rest until tomorrow to regain health.';
      } else if (healthyCards < 5) {
        errorMessage +=
            'You need at least 5 healthy cards to play this game. Currently you have $healthyCards healthy cards.';
      } else {
        errorMessage +=
            'There seems to be an issue with card availability. Please try again or contact support.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 6),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Shuffle and limit cards if needed
    filteredCards.shuffle();
    final desiredCount = widget.selectedCardCount >= 50
        ? filteredCards.length
        : widget.selectedCardCount;
    final clampedCount = desiredCount.clamp(1, filteredCards.length);
    final cardCount = clampedCount is int ? clampedCount : clampedCount.toInt();
    if (filteredCards.length > cardCount) {
      filteredCards = filteredCards.take(cardCount).toList();
    }

    // Only show warning if defeated cards would have been in the study set
    // OR if almost all cards are defeated (making it hard to create games)
    final totalCardsInPool = filteredCards.length + limitedCards.length;
    final defeatedRatio = totalCardsInPool > 0
        ? limitedCards.length / totalCardsInPool
        : 0.0;

    // Check if any defeated cards would have been selected (if we had more cards available)
    // This happens when the user requests more cards than are available due to defeated cards
    final requestedCount = widget.selectedCardCount >= 50
        ? availableCards.length
        : widget.selectedCardCount;
    final wouldHaveIncludedDefeated =
        requestedCount > availableCards.length && limitedCards.isNotEmpty;

    // Show warning only if:
    // 1. Defeated cards would have been in the study set, OR
    // 2. More than 80% of cards are defeated (making it hard to create games)
    if ((wouldHaveIncludedDefeated || defeatedRatio > 0.8) &&
        limitedCards.isNotEmpty &&
        availableCards.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${limitedCards.length} cards are defeated (0 HP). They need to rest until tomorrow to regain health.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    Navigator.of(context).pop();

    // Create title from selected deck names
    String title = selectedDeckNames.length == 1
        ? selectedDeckNames.first
        : '${selectedDeckNames.length} Decks';

    // Navigate based on game mode
    switch (widget.gameMode) {
      case GameMode.study:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdvancedStudyView(
              cards: filteredCards,
              startFlipped: widget.startFlipped,
              title: title,
              studyConfig: StudyConfig(
                deckIds: _selectedDeckIds.toList(),
                deckNames: _selectedDeckIds.isEmpty
                    ? ['All Decks']
                    : _selectedDeckIds
                          .map(
                            (id) =>
                                widget.decks.firstWhere((d) => d.id == id).name,
                          )
                          .toList(),
                cardCount: filteredCards.length,
                useSRSFiltering: widget.useSRSFiltering,
                startFlipped: widget.startFlipped,
                autoProgress: widget.autoProgress,
                useLivesMode: widget.useLivesMode,
                customLives: widget.customLives,
                useTimedMode: widget.useTimedMode,
                timedDifficulty: widget.timedDifficulty,
                timePerQuestion: _getTimePerQuestion(),
                useAllCardsForAnswers: widget.useAllCardsForAnswers,
                oneAnswerMode: false,
              ),
            ),
          ),
        );
        break;
      case GameMode.test:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MultipleChoiceView(
              cards: filteredCards,
              title: title,
              autoProgress: widget.autoProgress,
              useLivesMode: widget.useLivesMode,
              customLives: widget.customLives,
              startFlipped: widget.startFlipped,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
              answerPoolCards: _useAllCardsForAnswers
                  ? widget.provider.cards
                  : allSelectedCards,
              studyConfig: StudyConfig(
                deckIds: _selectedDeckIds.toList(),
                deckNames: _selectedDeckIds
                    .map(
                      (id) => widget.decks.firstWhere((d) => d.id == id).name,
                    )
                    .toList(),
                cardCount: filteredCards.length,
                useSRSFiltering: widget.useSRSFiltering,
                startFlipped: widget.startFlipped,
                autoProgress: widget.autoProgress,
                useLivesMode: widget.useLivesMode,
                customLives: widget.customLives,
                useTimedMode: widget.useTimedMode,
                timedDifficulty: widget.timedDifficulty,
                timePerQuestion: _getTimePerQuestion(),
                useAllCardsForAnswers: _useAllCardsForAnswers,
                oneAnswerMode: widget.oneAnswerMode,
              ),
            ),
          ),
        );
        break;
      case GameMode.trueFalse:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TrueFalseView(
              cards: filteredCards,
              title: title,
              autoProgress: widget.autoProgress,
              useLivesMode: widget.useLivesMode,
              customLives: widget.customLives,
              startFlipped: widget.startFlipped,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
              answerPoolCards: _useAllCardsForAnswers
                  ? widget.provider.cards
                  : allSelectedCards,
              studyConfig: StudyConfig(
                deckIds: _selectedDeckIds.toList(),
                deckNames: _selectedDeckIds
                    .map(
                      (id) => widget.decks.firstWhere((d) => d.id == id).name,
                    )
                    .toList(),
                cardCount: filteredCards.length,
                useSRSFiltering: widget.useSRSFiltering,
                startFlipped: widget.startFlipped,
                autoProgress: widget.autoProgress,
                useLivesMode: widget.useLivesMode,
                customLives: widget.customLives,
                useTimedMode: widget.useTimedMode,
                timedDifficulty: widget.timedDifficulty,
                timePerQuestion: _getTimePerQuestion(),
                useAllCardsForAnswers: _useAllCardsForAnswers,
                oneAnswerMode: false,
              ),
            ),
          ),
        );
        break;
      case GameMode.write:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WritingView(
              cards: allSelectedCards,
              title: title,
              startFlipped: widget.startFlipped,
              useLivesMode: widget.useLivesMode,
              customLives: widget.customLives,
              useTimedMode: widget.useTimedMode,
              timePerQuestion: _getTimePerQuestion(),
              autoProgress: widget.autoProgress,
            ),
          ),
        );
        break;
      case GameMode.game:
        // Timed mode removed for memory game
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MemoryGameView(
              cards: filteredCards,
              startFlipped: widget.startFlipped,
            ),
          ),
        );
        break;
      case GameMode.pickYourCard:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PickYourCardView(
              cards: filteredCards,
              title: title,
              autoProgress: widget.autoProgress,
              useLivesMode: widget.useLivesMode,
              customLives: widget.useLivesMode ? widget.customLives : null,
            ),
          ),
        );
        break;
      case GameMode.popYourCard:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PopYourCardView(
              cards: filteredCards,
              title: title,
              useLivesMode: widget.useLivesMode,
              customLives: widget.useLivesMode ? widget.customLives : null,
              useTimedMode: widget.useTimedMode,
              timePerQuestion: widget.useTimedMode
                  ? _getTimePerQuestion()
                  : null,
            ),
          ),
        );
        break;
      case GameMode.connectCards:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ConnectCardsView(
              cards: filteredCards,
              title: title,
              autoProgress: widget.autoProgress,
              useLivesMode: widget.useLivesMode,
              customLives: widget.customLives,
              useTimedMode: widget.useTimedMode,
              timePerQuestion: widget.useTimedMode
                  ? _getTimePerQuestion()
                  : null,
            ),
          ),
        );
        break;
      case GameMode.wordScramble:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WordScrambleView(
              cards: filteredCards,
              title: title,
              autoProgress: widget.autoProgress,
              useLivesMode: widget.useLivesMode,
              customLives: widget.customLives,
              startFlipped: widget.startFlipped,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
            ),
          ),
        );
        break;
      case GameMode.sentenceBuilding:
        final cardsWithSentences = filteredCards
            .where((c) => c.example.isNotEmpty)
            .toList();

        if (cardsWithSentences.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No cards with sentences available in selected decks.',
              ),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SentenceBuildingView(
              cards: cardsWithSentences,
              title: 'Sentence your cards',
              autoProgress: widget.autoProgress,
              useLivesMode: widget.useLivesMode,
              customLives: widget.useLivesMode ? widget.customLives : null,
              startFlipped: widget.startFlipped,
              oneAnswerMode: widget.oneAnswerMode,
              enableHints: true,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
            ),
          ),
        );
        break;
      case GameMode.deHet:
        final cardsWithArticles = filteredCards
            .where((c) => c.article == 'de' || c.article == 'het')
            .toList();

        if (cardsWithArticles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No cards with articles available in selected decks.',
              ),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DeHetView(
              cards: cardsWithArticles,
              title: 'De of Het',
              useLivesMode: widget.useLivesMode,
              customLives: widget.useLivesMode ? widget.customLives : null,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
              studyConfig: StudyConfig(
                deckIds: _selectedDeckIds.toList(),
                deckNames: _selectedDeckIds
                    .map(
                      (id) => widget.decks.firstWhere((d) => d.id == id).name,
                    )
                    .toList(),
                cardCount: cardsWithArticles.length,
                useSRSFiltering: widget.useSRSFiltering,
                startFlipped: widget.startFlipped,
                autoProgress: widget.autoProgress,
                useLivesMode: widget.useLivesMode,
                customLives: widget.customLives,
                useTimedMode: widget.useTimedMode,
                timedDifficulty: widget.timedDifficulty,
                timePerQuestion: _getTimePerQuestion(),
                useAllCardsForAnswers: widget.useAllCardsForAnswers,
                oneAnswerMode: false,
              ),
            ),
          ),
        );
        break;
      case GameMode.soManyCards:
        final cardsWithPlurals = filteredCards
            .where((c) => c.plural.isNotEmpty)
            .toList();

        if (cardsWithPlurals.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No cards with plural forms available in selected decks.',
              ),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SoManyCardsView(
              cards: cardsWithPlurals,
              title: 'So Many Cards',
              useLivesMode: widget.useLivesMode,
              customLives: widget.useLivesMode ? widget.customLives : null,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
              studyConfig: StudyConfig(
                deckIds: _selectedDeckIds.toList(),
                deckNames: _selectedDeckIds
                    .map(
                      (id) => widget.decks.firstWhere((d) => d.id == id).name,
                    )
                    .toList(),
                cardCount: cardsWithPlurals.length,
                useSRSFiltering: widget.useSRSFiltering,
                startFlipped: widget.startFlipped,
                autoProgress: widget.autoProgress,
                useLivesMode: widget.useLivesMode,
                customLives: widget.customLives,
                useTimedMode: widget.useTimedMode,
                timedDifficulty: widget.timedDifficulty,
                timePerQuestion: _getTimePerQuestion(),
                useAllCardsForAnswers: widget.useAllCardsForAnswers,
                oneAnswerMode: false,
              ),
            ),
          ),
        );
        break;
      case GameMode.timeYourCards:
        final cardsWithVerbs = filteredCards
            .where(
              (c) =>
                  c.presentTense.isNotEmpty ||
                  c.pastTense.isNotEmpty ||
                  c.perfectTense.isNotEmpty,
            )
            .toList();

        if (cardsWithVerbs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No cards with verb forms available in selected decks.',
              ),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TimeYourCardsView(
              cards: cardsWithVerbs,
              title: 'Time Your Cards',
              useLivesMode: widget.useLivesMode,
              customLives: widget.useLivesMode ? widget.customLives : null,
              useTimedMode: widget.useTimedMode,
              timedDifficulty: widget.timedDifficulty,
              studyConfig: StudyConfig(
                deckIds: _selectedDeckIds.toList(),
                deckNames: _selectedDeckIds
                    .map(
                      (id) => widget.decks.firstWhere((d) => d.id == id).name,
                    )
                    .toList(),
                cardCount: cardsWithVerbs.length,
                useSRSFiltering: widget.useSRSFiltering,
                startFlipped: widget.startFlipped,
                autoProgress: widget.autoProgress,
                useLivesMode: widget.useLivesMode,
                customLives: widget.customLives,
                useTimedMode: widget.useTimedMode,
                timedDifficulty: widget.timedDifficulty,
                timePerQuestion: _getTimePerQuestion(),
                useAllCardsForAnswers: widget.useAllCardsForAnswers,
                oneAnswerMode: false,
              ),
            ),
          ),
        );
        break;
    }
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDecks = _searchText.isEmpty
        ? widget.decks
        : widget.decks
              .where(
                (d) => d.name.toLowerCase().contains(_searchText.toLowerCase()),
              )
              .toList();

    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Decks'),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search decks...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchText = '';
                        });
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value;
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height:
            MediaQuery.of(context).size.height *
            0.6, // Use 60% of screen height
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summary of selected decks (only show if not searching or if items selected)
              if (_selectedDeckIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedDeckIds.length} deck${_selectedDeckIds.length == 1 ? '' : 's'} selected • $_totalSelectedCards cards',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_selectedDeckIds.isNotEmpty) const SizedBox(height: 16),

              // Deck list
              if (filteredDecks.isEmpty) ...[
                const SizedBox(height: 32),
                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No decks found matching "$_searchText"',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ] else ...[
                ...filteredDecks.map((deck) {
                  // For parent decks, include sub-deck cards; for sub-decks, only their own cards
                  final deckCards = deck.isSubDeck
                      ? widget.provider.getCardsForDeck(deck.id)
                      : widget.provider.getCardsForDeckWithSubDecks(deck.id);
                  final isSelected = _selectedDeckIds.contains(deck.id);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: CheckboxListTile(
                      title: Text(deck.name),
                      subtitle: Text('${deckCards.length} cards'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        _toggleDeckSelection(deck.id);
                      },
                      secondary: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_selectedDeckIds.isNotEmpty)
          TextButton(
            onPressed: () {
              setState(() {
                _selectedDeckIds.clear();
              });
              _calculateTotalCards();
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDeckIds.isNotEmpty ? _startStudy : null,
          child: const Text('Start Study'),
        ),
      ],
    );
  }
}
