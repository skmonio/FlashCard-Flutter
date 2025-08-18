import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/store_provider.dart';

import 'unified_import_export_view.dart';
import '../providers/user_profile_provider.dart';
import '../services/haptic_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _soundEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Header - wrapped in SafeArea to avoid system UI
          SafeArea(
            child: _buildHeader(context),
          ),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Settings
                  _buildAppSettingsSection(context),
                  const SizedBox(height: 24),
                  
                  // Data Management
                  _buildDataManagementSection(context),
                  const SizedBox(height: 24),
                  
                  // About
                  _buildAboutSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Profile button placeholder
          const SizedBox(width: 48),
          const Spacer(),
          // Title
          const Text(
            'Taal Trek',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Settings icon placeholder
          const SizedBox(width: 48),
        ],
      ),
    );
  }



  Widget _buildAppSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: Icon(
                      themeProvider.isSystemMode 
                          ? Icons.brightness_auto 
                          : themeProvider.isDarkMode 
                              ? Icons.dark_mode 
                              : Icons.light_mode,
                      color: themeProvider.isSystemMode 
                          ? Colors.blue 
                          : themeProvider.isDarkMode 
                              ? Colors.purple 
                              : Colors.orange,
                    ),
                    title: const Text('Theme'),
                    subtitle: Text(
                      themeProvider.isSystemMode 
                          ? 'System (auto)' 
                          : themeProvider.isDarkMode 
                              ? 'Dark mode' 
                              : 'Light mode',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showThemeSelectionDialog(context, themeProvider);
                    },
                  );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Play sounds during study'),
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() {
                    _soundEnabled = value;
                  });
                  // TODO: Implement sound settings
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Haptic Feedback'),
                subtitle: const Text('Vibrate on interactions'),
                value: HapticService().hapticEnabled,
                onChanged: (value) async {
                  await HapticService().setHapticEnabled(value);
                  setState(() {});
                  // Provide haptic feedback for the setting change
                  HapticService().buttonTapFeedback();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildDataManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [

              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Import/Export'),
                subtitle: const Text('Import/export flashcards with exercises'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UnifiedImportExportView(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Clear Data', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Delete all flashcards and settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                onTap: () {
                  _showClearDataDialog(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About Taal Trek'),
                subtitle: const Text('Learn more about the app'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help & Support'),
                subtitle: const Text('Get help and contact support'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Navigate to help
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Help section coming soon!')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Rate the App'),
                subtitle: const Text('Share your feedback'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // TODO: Open app store rating
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rating feature coming soon!')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ClearDataSelectionDialog(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Taal Trek'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text('A Dutch language learning app with interactive flashcards and games.'),
            SizedBox(height: 16),
            Text('Features:'),
            Text('• Spaced repetition learning'),
            Text('• Multiple study modes'),
            Text('• Interactive games'),
            Text('• Progress tracking'),
            Text('• Cloud sync (coming soon)'),
          ],
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



  void _showResetXpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset XP & Progress'),
        content: const Text(
          'This will reset all your XP, levels, achievements, and progress statistics. '
          'This action cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetXpAndProgress(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetXpAndProgress(BuildContext context) async {
    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      await userProfileProvider.resetXpAndProgress();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('XP and progress reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting XP: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.system,
              'System (Auto)',
              'Follows your device settings',
              Icons.brightness_auto,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.light,
              'Light Mode',
              'Always use light theme',
              Icons.light_mode,
              Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildThemeOption(
              context,
              themeProvider,
              ThemeMode.dark,
              'Dark Mode',
              'Always use dark theme',
              Icons.dark_mode,
              Colors.purple,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeProvider themeProvider,
    ThemeMode mode,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = themeProvider.themeMode == mode;
    
    return Card(
      margin: EdgeInsets.zero,
      color: isSelected ? color.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? color : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected 
            ? Icon(Icons.check, color: color)
            : null,
        onTap: () {
          themeProvider.setThemeMode(mode);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

class _ClearDataSelectionDialog extends StatefulWidget {
  @override
  State<_ClearDataSelectionDialog> createState() => _ClearDataSelectionDialogState();
}

class _ClearDataSelectionDialogState extends State<_ClearDataSelectionDialog> {
  Set<String> _selectedOptions = {};

  void _toggleOption(String option) {
    setState(() {
      if (_selectedOptions.contains(option)) {
        _selectedOptions.remove(option);
      } else {
        _selectedOptions.add(option);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedOptions = {
        'cards',
        'exercises',
        'stats',
        'everything',
      };
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedOptions.clear();
    });
  }

  Future<void> _executeClear(BuildContext context) async {
    if (_selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one option to clear'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    try {
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('cards')) {
        await _clearAllCards(context);
      }
      
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('exercises')) {
        await _clearAllExercises(context);
      }
      
      if (_selectedOptions.contains('everything') || _selectedOptions.contains('stats')) {
        await _clearAllStats(context);
      }

      if (mounted) {
        String message = 'Cleared: ';
        if (_selectedOptions.contains('everything')) {
          message = 'All data cleared successfully';
        } else {
          List<String> cleared = [];
          if (_selectedOptions.contains('cards')) cleared.add('cards');
          if (_selectedOptions.contains('exercises')) cleared.add('exercises');
          if (_selectedOptions.contains('stats')) cleared.add('stats & progress');
          message += cleared.join(', ');
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllCards(BuildContext context) async {
    final flashcardProvider = context.read<FlashcardProvider>();
    
    // Clear all cards
    final cards = List.from(flashcardProvider.cards);
    for (final card in cards) {
      await flashcardProvider.deleteCard(card.id);
    }
    
    // Clear all decks (except default ones)
    final decks = List.from(flashcardProvider.decks);
    for (final deck in decks) {
      if (deck.name != 'Uncategorized' && deck.name != 'Default') {
        await flashcardProvider.deleteDeck(deck.id);
      }
    }
  }

  Future<void> _clearAllExercises(BuildContext context) async {
    try {
      final dutchProvider = context.read<DutchWordExerciseProvider>();
      await dutchProvider.clearAllExercises();
    } catch (e) {
      print('DutchWordExerciseProvider not available: $e');
    }
  }

  Future<void> _clearAllStats(BuildContext context) async {
    try {
      final userProfileProvider = context.read<UserProfileProvider>();
      await userProfileProvider.resetXpAndProgress();
    } catch (e) {
      print('UserProfileProvider not available: $e');
    }
    
    try {
      final storeProvider = context.read<StoreProvider>();
      await storeProvider.clearAllUnlockedPacks();
    } catch (e) {
      print('StoreProvider not available: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clear Data'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select what you want to clear:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            
            // Select All / Clear All buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectAll,
                    child: const Text('Select All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearSelection,
                    child: const Text('Clear All'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Options
            _buildOptionTile(
              'cards',
              'All Cards & Decks',
              'Delete all flashcards and custom decks',
              Icons.style,
              Colors.blue,
            ),
            _buildOptionTile(
              'exercises',
              'All Exercises',
              'Delete all Dutch word exercises',
              Icons.quiz,
              Colors.green,
            ),
            _buildOptionTile(
              'stats',
              'Stats & Progress',
              'Reset XP, levels, achievements, and progress',
              Icons.analytics,
              Colors.orange,
            ),
            _buildOptionTile(
              'everything',
              'Everything',
              'Clear all data (cards, exercises, stats)',
              Icons.delete_forever,
              Colors.red,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => _executeClear(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Clear Selected'),
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    String option,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedOptions.contains(option);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: CheckboxListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: isSelected,
        onChanged: (bool? value) {
          _toggleOption(option);
        },
        secondary: Icon(
          icon,
          color: color,
        ),
        activeColor: color,
      ),
    );
  }
} 