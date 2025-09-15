import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_profile_provider.dart';
import '../services/supabase_service.dart';
import 'main_navigation_view.dart';

class UsernameSetupView extends StatefulWidget {
  const UsernameSetupView({super.key});

  @override
  State<UsernameSetupView> createState() => _UsernameSetupViewState();
}

class _UsernameSetupViewState extends State<UsernameSetupView> {
  final TextEditingController _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Set a default username based on email
    final user = SupabaseService.instance.currentUser;
    if (user?.email != null) {
      final emailPrefix = user!.email!.split('@')[0];
      _usernameController.text = emailPrefix;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      
      // Check if username is available
      final isAvailable = await _checkUsernameAvailability(username);
      if (!isAvailable) {
        setState(() {
          _errorMessage = 'Username is already taken. Please choose another.';
          _isLoading = false;
        });
        return;
      }

      // Update user profile with username
      final userProfileProvider = context.read<UserProfileProvider>();
      await userProfileProvider.updateUsername(username);
      
      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigationView()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save username: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    try {
      final response = await SupabaseService.instance.client
          .from('user_profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      
      return response == null; // Available if no user found with this username
    } catch (e) {
      print('Error checking username availability: $e');
      return true; // Assume available if check fails
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a username';
    }
    
    final username = value.trim();
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    
    if (username.length > 20) {
      return 'Username must be less than 20 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // Welcome message
              Text(
                'Welcome to Taal Trek!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'Choose a username to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Username form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        errorText: _errorMessage,
                      ),
                      validator: _validateUsername,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _saveUsername(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Username requirements
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Username requirements:',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('• 3-20 characters long'),
                          const Text('• Letters, numbers, and underscores only'),
                          const Text('• Must be unique'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveUsername,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Skip button
              TextButton(
                onPressed: _isLoading ? null : () {
                  // Use default username and continue
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const MainNavigationView()),
                  );
                },
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

