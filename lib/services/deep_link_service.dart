import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'supabase_service.dart';
import 'data_sync_service.dart';
import '../utils/global_navigator.dart';
import '../views/onboarding_view.dart';
import '../providers/flashcard_provider.dart';
import '../providers/user_profile_provider.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();
  
  static final AppLinks _appLinks = AppLinks();
  
  // Handle incoming deep links
  static Future<void> handleDeepLink(String link) async {
    print('🔗 Deep link received: $link');
    
    try {
      final uri = Uri.parse(link);
      print('🔗 Parsed URI: scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}');
      print('🔗 Query parameters: ${uri.queryParameters}');
      
      // Handle email verification
      if (uri.scheme == 'taaltrek' && uri.host == 'verify-email') {
        final token = uri.queryParameters['token'];
        final type = uri.queryParameters['type'];
        
        print('📧 Email verification - token: $token, type: $type');
        
        if (token != null && type != null) {
          try {
            await SupabaseService.instance.verifyEmail(
              token: token,
              type: type,
            );
            print('✅ Email verified successfully');
            
            // Show success message
            _showVerificationSuccess();
          } catch (e) {
            print('❌ Error verifying email: $e');
            _showVerificationError(e.toString());
          }
        }
      }
      
      // Handle login callback
      if (uri.scheme == 'taaltrek' && uri.host == 'login-callback') {
        print('🔐 Login callback received');
        // Handle any additional login callback logic here
      }
      
    } catch (e) {
      print('❌ Error handling deep link: $e');
    }
  }
  
  // Initialize deep link listening
  static void initialize() {
    print('🔗 Initializing deep link service');
    
    // Listen for app links when app is already running
    _appLinks.uriLinkStream.listen((Uri uri) {
      print('🔗 App link stream received: $uri');
      handleDeepLink(uri.toString());
    }, onError: (err) {
      print('❌ App link stream error: $err');
    });
    
    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      print('🔐 Auth state changed: $event');
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        print('✅ User signed in successfully');
        // Sync data when user signs in
        _handleUserSignIn();
      } else if (event == AuthChangeEvent.signedOut) {
        print('👋 User signed out');
      }
    });
    
    // Handle initial link if app was opened via deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        print('🔗 Initial app link: $uri');
        handleDeepLink(uri.toString());
      }
    });
  }
  
  // Show verification success message
  static void _showVerificationSuccess() {
    print('🎉 Email verification successful! You can now sign in.');
    
    // Show success dialog
    GlobalNavigator.showAlertDialog(
      title: 'Email Verified! 🎉',
      content: 'Your email has been successfully verified! You can now sign in to your account.',
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(GlobalNavigator.currentContext!).pop();
            _checkAndShowOnboarding();
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
  
  // Show verification error message
  static void _showVerificationError(String error) {
    print('❌ Email verification failed: $error');
    
    GlobalNavigator.showAlertDialog(
      title: 'Verification Failed',
      content: 'There was an error verifying your email. Please try again or contact support.',
    );
  }
  
  // Check if user needs onboarding and show it
  static Future<void> _checkAndShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      
      if (!onboardingCompleted) {
        // Show onboarding
        Navigator.of(GlobalNavigator.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => OnboardingView(
              isFirstTime: true,
              onOnboardingComplete: () {
                Navigator.of(context).pop();
                GlobalNavigator.showSnackBar('Welcome to Taal Trek! 🎓');
              },
            ),
          ),
        );
      } else {
        GlobalNavigator.showSnackBar('Welcome back! You can now sign in. 🎓');
      }
    } catch (e) {
      print('❌ Error checking onboarding status: $e');
      GlobalNavigator.showSnackBar('Welcome! You can now sign in. 🎓');
    }
  }
  
  // Handle user sign in - sync data
  static Future<void> _handleUserSignIn() async {
    try {
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
      
      print('🔄 Deep link - Has user data: $hasUserData');
      
      if (hasUserData) {
        // Upload local data to cloud
        print('🔄 Uploading local data to cloud...');
        await DataSyncService.syncAllData();
        GlobalNavigator.showSnackBar('Data synced to cloud! ☁️');
      } else {
        // Download data from cloud
        print('🔄 Downloading data from cloud...');
        await DataSyncService.downloadDataFromCloud();
        GlobalNavigator.showSnackBar('Data synced from cloud! ☁️');
      }
      
      // Refresh providers after data sync
      print('🔄 Refreshing providers after deep link sync...');
      final context = GlobalNavigator.currentContext;
      print('🔄 Context is null: ${context == null}');
      
      if (context != null) {
        try {
          print('🔄 Attempting to refresh FlashcardProvider...');
          final flashcardProvider = context.read<FlashcardProvider>();
          await flashcardProvider.initialize();
          
          print('🔄 Attempting to refresh UserProfileProvider...');
          final userProfileProvider = context.read<UserProfileProvider>();
          await userProfileProvider.initialize();
          
          print('✅ Providers refreshed successfully');
        } catch (e) {
          print('❌ Error refreshing providers: $e');
        }
      } else {
        print('❌ Context is null, cannot refresh providers');
      }
    } catch (e) {
      print('❌ Error during data sync: $e');
      GlobalNavigator.showSnackBar('Data sync failed, but you can still use the app');
    }
  }
}
