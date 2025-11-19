import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';
import '../providers/translation_language_provider.dart';


import 'unified_import_export_view.dart';
import 'clear_data_view.dart';
import 'onboarding_view.dart';
import 'auth_view.dart';
import 'help_center_view.dart';
import '../providers/user_profile_provider.dart';
import '../services/haptic_service.dart';
import '../services/sound_manager.dart';
import '../services/supabase_service.dart';
import '../utils/global_navigator.dart';
import '../services/sample_data_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isAddingSampleData = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    // Initialize sound provider
    final soundProvider = context.read<SoundProvider>();
    await soundProvider.initialize();
    
    // Initialize sound manager with the provider
    await SoundManager().initialize(soundProvider: soundProvider);
    SoundManager().setSoundProvider(soundProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Management
            _buildAccountSection(context),
            const SizedBox(height: 24),
            
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
              Consumer<SoundProvider>(
                builder: (context, soundProvider, child) {
                  return ListTile(
                    leading: Icon(
                      soundProvider.getIcon(soundProvider.soundMode),
                      color: soundProvider.getColor(soundProvider.soundMode),
                    ),
                    title: const Text('Sound Effects'),
                    subtitle: Text(soundProvider.getDisplayName(soundProvider.soundMode)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showSoundSelectionDialog(context, soundProvider);
                    },
                  );
                },
              ),
              const Divider(height: 1),
              Consumer<TranslationLanguageProvider>(
                builder: (context, langProvider, child) {
                  return ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: Colors.blue,
                    ),
                    title: const Text('Language'),
                    subtitle: Text('Word: ${langProvider.wordLanguage.toString()} | Translation: ${langProvider.translationLanguage.toString()}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      _showLanguageDialog(context, langProvider);
                    },
                  );
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
              Consumer<FlashcardProvider>(
                builder: (context, flashcardProvider, child) {
                  final trailingWidget = _isAddingSampleData
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16);

                  return ListTile(
                    leading: const Icon(Icons.library_add),
                    title: const Text('Add Starter Cards'),
                    subtitle: const Text('Restore the Dutch Basics sample deck'),
                    trailing: trailingWidget,
                    onTap: _isAddingSampleData
                        ? null
                        : () => _handleAddSampleData(context, flashcardProvider),
                  );
                },
              ),
              const Divider(height: 1),

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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ClearDataView(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddSampleData(
    BuildContext context,
    FlashcardProvider provider,
  ) async {
    if (_isAddingSampleData) return;

    setState(() {
      _isAddingSampleData = true;
    });

    try {
      final result = await SampleDataService.addSampleData(provider);

      if (!mounted) return;

      HapticService().buttonTapFeedback();

      String message;
      if (result.totalChanges > 0) {
        final additions = result.newCardsCreated;
        final reattachments = result.cardsReattached;

        final parts = <String>[];
        if (additions > 0) {
          parts.add('$additions new card${additions == 1 ? '' : 's'} added');
        }
        if (reattachments > 0) {
          parts.add('${reattachments == 1 ? '1 card' : '$reattachments cards'} restored');
        }

        message = 'Dutch Basics updated: ${parts.join(' and ')}.';
      } else {
        message = 'Dutch Basics sample cards are already available.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding sample cards: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingSampleData = false;
        });
      }
    }
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const HelpCenterView(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('Show Onboarding'),
                subtitle: const Text('Learn how to use the app'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const OnboardingView(
                        isFirstTime: false,
                        onOnboardingComplete: null, // No callback needed for settings
                      ),
                    ),
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



  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Taal Trek'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Version 3.3.4',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your personalized Dutch language learning companion with AI-powered features and gamified study modes.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Interactive flashcards with spaced repetition'),
              const Text('• Multiple study modes (Test, True/False, Write, Memory, etc.)'),
              const Text('• Shuffle mode for mixed learning'),
              const Text('• AI-powered text recognition'),
              const Text('• Comprehensive grammar exercises'),
              const Text('• Progress tracking and XP system'),
              const Text('• Cloud sync across devices'),
              const Text('• Multiple language support'),
              const SizedBox(height: 16),
              Text(
                'Master Dutch vocabulary through engaging games and real-world text scanning.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
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

  void _showSoundSelectionDialog(BuildContext context, SoundProvider soundProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Sound Setting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSoundOption(
              context,
              soundProvider,
              SoundMode.system,
              'System (Auto)',
              'Follow device silent mode settings',
              Icons.volume_up_outlined,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildSoundOption(
              context,
              soundProvider,
              SoundMode.always,
              'Sound On',
              'Always play sounds',
              Icons.volume_up,
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildSoundOption(
              context,
              soundProvider,
              SoundMode.never,
              'Sound Off',
              'Never play sounds',
              Icons.volume_off,
              Colors.red,
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

  void _showLanguageDialog(
    BuildContext context,
    TranslationLanguageProvider langProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language Settings'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: DefaultTabController(
            length: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.language, color: Colors.green),
                      text: 'Word Language',
                    ),
                    Tab(
                      icon: Icon(Icons.translate, color: Colors.blue),
                      text: 'Translation Language',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Word Language Tab
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Select the language you want to learn',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: TranslationLanguageProvider.availableLanguages.length,
                              itemBuilder: (context, index) {
                                final language = TranslationLanguageProvider.availableLanguages[index];
                                final isSelected = langProvider.wordLanguage.code == language.code;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                                  color: isSelected ? Colors.green.withValues(alpha: 0.1) : null,
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.language,
                                      color: isSelected ? Colors.green : Colors.grey,
                                    ),
                                    title: Text(
                                      language.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.green : null,
                                      ),
                                    ),
                                    subtitle: Text(language.nativeName),
                                    trailing: isSelected 
                                        ? const Icon(Icons.check, color: Colors.green)
                                        : null,
                                    onTap: () {
                                      langProvider.setWordLanguage(language);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      // Translation Language Tab
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Select the language for translations',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: TranslationLanguageProvider.availableLanguages.length,
                              itemBuilder: (context, index) {
                                final language = TranslationLanguageProvider.availableLanguages[index];
                                final isSelected = langProvider.translationLanguage.code == language.code;
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                                  color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.translate,
                                      color: isSelected ? Colors.blue : Colors.grey,
                                    ),
                                    title: Text(
                                      language.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.blue : null,
                                      ),
                                    ),
                                    subtitle: Text(language.nativeName),
                                    trailing: isSelected 
                                        ? const Icon(Icons.check, color: Colors.blue)
                                        : null,
                                    onTap: () {
                                      langProvider.setTranslationLanguage(language);
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundOption(
    BuildContext context,
    SoundProvider soundProvider,
    SoundMode mode,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = soundProvider.soundMode == mode;
    
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
          soundProvider.setSoundMode(mode);
          Navigator.of(context).pop();
        },
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

  Widget _buildAccountSection(BuildContext context) {
    final isAuthenticated = SupabaseService.instance.isAuthenticated;
    final currentUser = SupabaseService.instance.currentUser;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
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
              if (isAuthenticated && currentUser != null) ...[
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: const Text('Signed In'),
                  subtitle: Text(currentUser.email ?? 'No email'),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: Colors.orange),
                  title: const Text('Sync Status'),
                  subtitle: const Text('Your data syncs automatically'),
                  trailing: const Icon(Icons.cloud_done, color: Colors.green),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: const Text('Change Password'),
                  subtitle: const Text('Update your account password'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showChangePasswordDialog(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Sign out of your account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                  onTap: () {
                    _showSignOutDialog(context);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.login, color: Colors.blue),
                  title: const Text('Sign In / Create Account'),
                  subtitle: const Text('Sign in or create an account to sync your data across devices'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthView()),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: const Text('We\'ll send you a password reset link to your email address. You can then set a new password.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _sendPasswordResetEmail(context);
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(BuildContext context) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user?.email != null) {
        await SupabaseService.instance.resetPassword(email: user!.email!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent to your email!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get your email address. Please sign out and use the forgot password option on the sign-in screen.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? Your data will remain synced to the cloud and you can sign back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _signOut(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await SupabaseService.instance.signOut();
      
      if (mounted) {
        GlobalNavigator.showSnackBar('Signed out successfully');
        // Navigate to auth screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthView()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        GlobalNavigator.showSnackBar('Error signing out: $e');
      }
    }
  }
}

 