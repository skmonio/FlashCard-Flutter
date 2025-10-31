import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/enhanced_snackbar.dart';
import 'main_navigation_view.dart';
import 'username_setup_view.dart';

class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // Check username availability before signup
        final username = _usernameController.text.trim();
        final isUsernameAvailable = await SupabaseService.instance.isUsernameAvailable(username);
        if (!isUsernameAvailable) {
          if (mounted) {
            EnhancedSnackBar.showError(
              context,
              message: 'Username "$username" is already taken. Please choose another.',
            );
          }
          return;
        }

        await SupabaseService.instance.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'username': username,
            'selected_avatar': 'person',
          },
        );
        if (mounted) {
          EnhancedSnackBar.showInfo(
            context,
            message: 'Check your email for verification link!',
          );
        }
      } else {
        await SupabaseService.instance.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          // Check if user has a username set
          final hasUsername = await _checkIfUserHasUsername();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => hasUsername 
                  ? const MainNavigationView()
                  : const UsernameSetupView(),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        String errorMessage = error.toString();
        
        // Provide more user-friendly error messages
        if (errorMessage.contains('validation_failed') && errorMessage.contains('email')) {
          errorMessage = 'Please check your email address format and try again.';
        } else if (errorMessage.contains('User already registered')) {
          errorMessage = 'An account with this email already exists. Please sign in instead.';
        } else if (errorMessage.contains('Password should be at least')) {
          errorMessage = 'Password must be at least 6 characters long.';
        } else if (errorMessage.contains('Invalid login credentials')) {
          errorMessage = 'Invalid email or password. Please check and try again.';
        } else if (errorMessage.contains('Database error')) {
          errorMessage = 'There was a problem creating your account. Please try again.';
        }
        
        EnhancedSnackBar.showError(
          context,
          message: errorMessage,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkIfUserHasUsername() async {
    try {
      final profile = await SupabaseService.instance.getUserProfile();
      if (profile != null) {
        final username = profile['username'] as String?;
        return username != null && username.isNotEmpty && username != 'Learner';
      }
      return false;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email address and we\'ll send you a password reset link.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.isNotEmpty) {
      try {
        await SupabaseService.instance.resetPassword(
          email: emailController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset link sent to your email!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Form(
                  key: _formKey,
                  child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.school,
                  size: 80,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(height: 32),
                Text(
                  'Taal Trek',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Dutch Learning Companion',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),
                // Mode indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSignUp ? Colors.green.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSignUp ? Colors.green.shade200 : Colors.blue.shade200,
                    ),
                  ),
                  child: Text(
                    _isSignUp ? 'Creating New Account' : 'Sign In to Your Account',
                    style: TextStyle(
                      color: _isSignUp ? Colors.green.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                    hintText: 'Enter your email address',
                  ),
                  onChanged: (value) {
                    // Auto-clean common email typos
                    if (value.contains(',') || value.contains(';')) {
                      final cleanedValue = value.replaceAll(RegExp(r'[,;]'), '');
                      _emailController.value = _emailController.value.copyWith(
                        text: cleanedValue,
                        selection: TextSelection.collapsed(offset: cleanedValue.length),
                      );
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    
                    // Clean the email value (remove extra spaces, commas, etc.)
                    final cleanEmail = value.trim().replaceAll(RegExp(r'[,;]'), '');
                    
                    // Check for basic email format
                    if (!cleanEmail.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    
                    // More comprehensive email validation
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(cleanEmail)) {
                      return 'Please enter a valid email address (e.g., user@example.com)';
                    }
                    
                    // Check for common typos
                    if (value.contains(',') || value.contains(';')) {
                      return 'Email contains invalid characters. Please remove commas or semicolons.';
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                // Email help text
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Enter a valid email address (e.g., yourname@example.com)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      hintText: 'Choose a unique username',
                    ),
                    validator: (value) {
                      if (_isSignUp) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
                        }
                        if (value.length > 20) {
                          return 'Username must be less than 20 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                          return 'Username can only contain letters, numbers, and underscores';
                        }
                      }
                      return null;
                    },
                    onChanged: (value) async {
                      if (_isSignUp && value.isNotEmpty && value.length >= 3) {
                        // Check username availability in real-time
                        final isAvailable = await SupabaseService.instance.isUsernameAvailable(value);
                        if (!isAvailable && mounted) {
                          // Show a subtle hint that username is taken
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Username "$value" is already taken'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Username help text
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose a unique username (3-20 characters, letters, numbers, and underscores only)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_isSignUp) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                      // Clear form fields when switching modes
                      _emailController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                      _usernameController.clear();
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                  ),
                ),
                if (!_isSignUp) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Skip authentication for now (for testing)
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const MainNavigationView()),
                    );
                  },
                  child: const Text('Continue without account (Offline mode)'),
                ),
              ],
            ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
