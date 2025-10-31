import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  
  SupabaseService._();
  
  SupabaseClient get client => Supabase.instance.client;
  
  // Initialize Supabase
  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase configuration is missing. Please update supabase_config.dart with your credentials.');
    }
    
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: true, // Set to false in production
    );
  }
  
  // Authentication helpers
  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  
  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: 'taaltrek://verify-email/',
    );
  }
  
  // Handle email verification
  Future<AuthResponse> verifyEmail({
    required String token,
    required String type,
  }) async {
    try {
      // For email verification, we need to use the correct OTP type
      OtpType otpType;
      if (type == 'signup') {
        otpType = OtpType.signup;
      } else if (type == 'email') {
        otpType = OtpType.email;
      } else {
        otpType = OtpType.signup; // Default to signup
      }
      
      // Use the correct verification method
      final response = await client.auth.verifyOTP(
        token: token,
        type: otpType,
      );
      
      // Ensure user profile exists after email verification
      if (response.user != null) {
        await ensureUserProfileExists();
      }
      
      return response;
    } catch (e) {
      print('❌ Error in verifyEmail: $e');
      rethrow;
    }
  }
  
  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    // Ensure user profile exists after sign in
    if (response.user != null) {
      await ensureUserProfileExists();
    }
    
    return response;
  }
  
  // Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  // Reset password
  Future<void> resetPassword({required String email}) async {
    await client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'taaltrek://reset-password/',
    );
  }
  
  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
  
  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await client
          .from('user_profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      
      return response == null; // Available if no user found with this username
    } catch (e) {
      print('❌ Error checking username availability: $e');
      return false; // Assume not available on error
    }
  }
  
  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isAuthenticated) return null;
    
    final response = await client
        .from('user_profiles')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();
    
    return response;
  }
  
  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> profile) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    await client
        .from('user_profiles')
        .upsert({
          'id': currentUser!.id,
          ...profile,
          'updated_at': DateTime.now().toIso8601String(),
        });
  }

  // Ensure user profile exists (create if not)
  Future<void> ensureUserProfileExists() async {
    if (!isAuthenticated) return;
    
    try {
      // Check if profile already exists
      final existingProfile = await getUserProfile();
      if (existingProfile != null) {
        print('✅ User profile already exists');
        return;
      }
      
      // Get username from user metadata or generate one
      String username;
      final userMetadata = currentUser!.userMetadata;
      if (userMetadata != null && userMetadata['username'] != null) {
        username = userMetadata['username'] as String;
      } else {
        // Generate a unique username based on email
        final email = currentUser!.email ?? 'user';
        username = email.split('@')[0] + '_${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      }
      
      // Get selected avatar from metadata or use default
      String selectedAvatar = 'person';
      if (userMetadata != null && userMetadata['selected_avatar'] != null) {
        selectedAvatar = userMetadata['selected_avatar'] as String;
      }
      
      // Create default profile with username from metadata
      print('🔧 Creating new user profile for ${currentUser!.id} with username: $username');
      await client
          .from('user_profiles')
          .insert({
            'id': currentUser!.id,
            'username': username,
            'selected_avatar': selectedAvatar,
            'profile_image_data': null,
            'xp': 0,
            'level': 1,
            'total_sessions': 0,
            'current_streak': 0,
            'best_streak': 0,
            'accuracy': 0.0,
            'total_cards_studied': 0,
            'perfect_sessions': 0,
            'onboarding_completed': false,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
      
      print('✅ User profile created successfully');
    } catch (e) {
      print('❌ Error ensuring user profile exists: $e');
      // Don't rethrow - this is a non-critical operation
    }
  }
}
