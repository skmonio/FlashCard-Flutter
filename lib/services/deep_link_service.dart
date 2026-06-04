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
      print(
        '🔗 Parsed URI: scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}',
      );
      print('🔗 Query parameters: ${uri.queryParameters}');

      // Handle password reset (recovery)
      if (uri.scheme == 'taaltrek' && uri.host == 'reset-password') {
        // Supabase may send token as token, token_hash or in the fragment as access_token
        String? token =
            uri.queryParameters['token'] ?? uri.queryParameters['token_hash'];
        String? type = uri.queryParameters['type'];

        // Some providers return params in the URL fragment (after '#')
        if ((token == null || token.isEmpty) && uri.fragment.isNotEmpty) {
          final fragParams = _parseFragmentParams(uri.fragment);
          token =
              fragParams['token'] ??
              fragParams['recovery_token'] ??
              fragParams['token_hash'] ??
              fragParams['access_token'];
          type = fragParams['type'] ?? type;
        }

        try {
          // If Supabase provided a recovery OTP token, verify it first
          if (token != null &&
              (type == 'recovery' || type == 'recovery_token')) {
            print('🔐 Verifying recovery token');
            await Supabase.instance.client.auth.verifyOTP(
              token: token,
              type: OtpType.recovery,
            );
          }

          // If no token was present, guide the user to open from email again
          if (token == null) {
            GlobalNavigator.showAlertDialog(
              title: 'Password reset link',
              content:
                  'We could not read a reset token. Please open the reset link directly from your email on this device. If the email is older than 60 minutes, request a new link and try again.',
            );
            return;
          }

          // Prompt user to set a new password and update it
          await _promptAndUpdatePassword();
        } catch (e) {
          print('❌ Error during password recovery flow: $e');
          _showVerificationError('Password reset failed: $e');
        }
      }

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
    _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('🔗 App link stream received: $uri');
        handleDeepLink(uri.toString());
      },
      onError: (err) {
        print('❌ App link stream error: $err');
      },
    );

    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print('🔐 Auth state changed: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        // Supabase established a recovery session from the link; prompt for new password
        print('🔐 Password recovery session established');
        await _promptAndUpdatePassword();
      } else if (event == AuthChangeEvent.signedIn && session != null) {
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
      content:
          'Your email has been successfully verified! You can now sign in to your account.',
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
      content:
          'There was an error verifying your email. Please try again or contact support.',
    );
  }

  // Parse key=value pairs from a URL fragment like "type=recovery&token=..."
  static Map<String, String> _parseFragmentParams(String fragment) {
    final Map<String, String> params = {};
    for (final part in fragment.split('&')) {
      final kv = part.split('=');
      if (kv.length == 2) {
        params[Uri.decodeComponent(kv[0])] = Uri.decodeComponent(kv[1]);
      }
    }
    return params;
  }

  // Prompt for new password and update via Supabase
  static Future<void> _promptAndUpdatePassword() async {
    final context = GlobalNavigator.currentContext;
    if (context == null) {
      print('❌ No navigator context available for password reset');
      return;
    }

    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set New Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter and confirm your new password to complete the reset.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Update Password'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Failed to update password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update password: $e'),
          backgroundColor: Colors.red,
        ),
      );
      rethrow;
    } finally {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  // Check if user needs onboarding and show it
  static Future<void> _checkAndShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

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
      // When signing in, always download from cloud first to get the user's existing data
      print('🔄 Downloading data from cloud...');
      final syncResult = await DataSyncService.downloadDataFromCloud();
      if (syncResult.isFailure) {
        GlobalNavigator.showErrorSnackBar(syncResult.message);
      } else {
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
      GlobalNavigator.showSnackBar(
        'Data sync failed, but you can still use the app',
      );
    }
  }
}
