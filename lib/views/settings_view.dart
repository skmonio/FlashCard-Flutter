import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/dutch_word_exercise_provider.dart';


import 'unified_import_export_view.dart';
import 'clear_data_view.dart';
import 'onboarding_view.dart';
import 'auth_view.dart';
import '../providers/user_profile_provider.dart';
import '../services/haptic_service.dart';
import '../services/sound_manager.dart';
import '../services/supabase_service.dart';
import '../utils/global_navigator.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSoundSettings();
  }

  Future<void> _loadSoundSettings() async {
    await SoundManager().initialize();
    setState(() {
      _soundEnabled = SoundManager().soundEnabled;
    });
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
              SwitchListTile(
                title: const Text('Sound Effects'),
                subtitle: const Text('Play sounds during study'),
                value: _soundEnabled,
                onChanged: (value) async {
                  setState(() {
                    _soundEnabled = value;
                  });
                  await SoundManager().setSoundEnabled(value);
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
                  leading: const Icon(Icons.person_outline, color: Colors.grey),
                  title: const Text('Not Signed In'),
                  subtitle: const Text('Sign in to sync your data across devices'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthView()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.blue),
                  title: const Text('Create Account'),
                  subtitle: const Text('Sign up for a new account'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthView()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.login, color: Colors.green),
                  title: const Text('Sign In'),
                  subtitle: const Text('Sign in to existing account'),
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

 