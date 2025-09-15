import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/sound_manager.dart';
import '../services/supabase_service.dart';
import '../services/data_sync_service.dart';
import 'loading_view.dart';
import 'main_navigation_view.dart';
import 'onboarding_view.dart';
import 'auth_view.dart';

class AppInitializationView extends StatefulWidget {
  const AppInitializationView({super.key});

  @override
  State<AppInitializationView> createState() => _AppInitializationViewState();
}

class _AppInitializationViewState extends State<AppInitializationView> {
  bool _themeInitialized = false;
  bool _onboardingCompleted = false;
  bool _isAuthenticated = false;
  bool _authChecked = false;
  bool _dataSynced = false;

  @override
  void initState() {
    super.initState();
    
    // Play begin sound when app loads
    SoundManager().playBeginSound();
    
    _initializeTheme();
    _checkAuthStatus();
  }

  Future<void> _initializeTheme() async {
    // Wait for theme provider to fully initialize
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.initialize();
    
    if (mounted) {
      setState(() {
        _themeInitialized = true;
      });
    }
  }
  
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    
    if (mounted) {
      setState(() {
        _onboardingCompleted = completed;
      });
    }
  }
  
  String _getLoadingText() {
    if (!_themeInitialized) {
      return 'Initializing theme...';
    } else if (!_authChecked) {
      return 'Checking authentication...';
    } else if (_isAuthenticated && !_dataSynced) {
      return 'Syncing your data...';
    } else {
      return 'Loading your Dutch learning journey...';
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isAuth = SupabaseService.instance.isAuthenticated;
      if (mounted) {
        setState(() {
          _isAuthenticated = isAuth;
          _authChecked = true;
        });
        
        // If authenticated, ensure profile exists and sync data
        if (isAuth) {
          await SupabaseService.instance.ensureUserProfileExists();
          await _syncDataAndCheckOnboarding();
        } else {
          // If not authenticated, check local onboarding status
          await _checkOnboardingStatus();
        }
      }
    } catch (e) {
      print('Error checking auth status: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _authChecked = true;
        });
        // Check local onboarding if auth fails
        await _checkOnboardingStatus();
      }
    }
  }
  
  Future<void> _syncDataAndCheckOnboarding() async {
    try {
      print('🔄 Syncing data for authenticated user...');
      
      // Check if this device has meaningful user data (not just system decks)
      final prefs = await SharedPreferences.getInstance();
      final decks = prefs.getStringList('decks') ?? [];
      final cards = prefs.getStringList('cards') ?? [];
      final userProfile = prefs.getString('user_profile');
      
      // Check if decks are more than just system decks (Uncategorized, Review)
      bool hasCustomDecks = false;
      if (decks.isNotEmpty) {
        for (final deckJson in decks) {
          try {
            final deckData = json.decode(deckJson);
            final deckName = deckData['name'] as String?;
            if (deckName != null && deckName != 'Uncategorized' && deckName != 'Review') {
              hasCustomDecks = true;
              break;
            }
          } catch (e) {
            // If we can't parse the deck, assume it's custom data
            hasCustomDecks = true;
            break;
          }
        }
      }
      
      final hasUserData = hasCustomDecks || cards.isNotEmpty || userProfile != null;
      
      print('🔄 Has user data: $hasUserData');
      print('🔄 Decks: ${prefs.getStringList('decks')?.length ?? 0}');
      print('🔄 Cards: ${prefs.getStringList('cards')?.length ?? 0}');
      print('🔄 Cards list: $cards');
      print('🔄 Cards isNotEmpty: ${cards.isNotEmpty}');
      print('🔄 Has custom decks: $hasCustomDecks');
      print('🔄 User profile: ${prefs.getString('user_profile') != null}');
      
      // When signing in, prioritize downloading from cloud to get user's existing data
      print('🔄 Downloading data from cloud...');
      if (mounted) {
        setState(() {
          // This will trigger a rebuild to show "Syncing your data..." message
        });
      }
      await DataSyncService.downloadDataFromCloud();
      
      // Then upload any local changes that might not be in cloud yet
      if (hasUserData) {
        print('🔄 Uploading local data to cloud...');
        await DataSyncService.syncAllData();
      }
      
      // Refresh providers after data sync to ensure UI shows latest data
      print('🔄 Refreshing providers after data sync...');
      if (mounted) {
        // Notify all providers to refresh their data
        final flashcardProvider = context.read<FlashcardProvider>();
        await flashcardProvider.initialize();
        
        final userProfileProvider = context.read<UserProfileProvider>();
        await userProfileProvider.initialize();
      }
      
      // Now check onboarding status (after data sync)
      await _checkOnboardingStatus();
      
      if (mounted) {
        setState(() {
          _dataSynced = true;
        });
      }
    } catch (e) {
      print('❌ Error during data sync: $e');
      // Still check onboarding even if sync fails
      await _checkOnboardingStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_themeInitialized || !_authChecked || (_isAuthenticated && !_dataSynced)) {
      // Show a basic splash screen while theme, auth, and data sync load
      final systemBrightness = MediaQuery.of(context).platformBrightness;
      final isDark = systemBrightness == Brightness.dark;
      
      return Material(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: isDark ? Colors.black : Colors.white,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  isDark ? 'assets/images/taal-trek-splash-dark.png' : 'assets/images/taal-trek-splash.png',
                  fit: BoxFit.contain,
                  width: 200,
                  height: 200,
                ),
                const SizedBox(height: 20),
                if (_isAuthenticated && !_dataSynced)
                  const Text(
                    'Syncing your data...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Check if user needs authentication
    if (!_isAuthenticated) {
      return const AuthView();
    }

    // Check if user needs onboarding (regardless of authentication status)
    if (!_onboardingCompleted) {
      return OnboardingView(
        isFirstTime: true,
        onOnboardingComplete: () {
          // When onboarding completes, check the status again and rebuild
          _checkOnboardingStatus();
        },
      );
    }
    
    // Once theme is initialized and user is authenticated, show the normal loading view
    return LoadingView(
      minimumDisplayTime: const Duration(milliseconds: 1500),
      isReadyCheck: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      },
      child: const MainNavigationView(),
    );
  }
}
