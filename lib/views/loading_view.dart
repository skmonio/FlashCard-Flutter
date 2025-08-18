import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class LoadingView extends StatefulWidget {
  final Widget child;
  final Duration minimumDisplayTime;
  final Future<bool> Function()? isReadyCheck;

  const LoadingView({
    super.key,
    required this.child,
    this.minimumDisplayTime = const Duration(seconds: 2),
    this.isReadyCheck,
  });

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView> {
  bool _showContent = false;
  String _loadingText = "Loading your Dutch learning journey...";

  @override
  void initState() {
    super.initState();
    _startLoadingSequence();
  }

  void _startLoadingSequence() {
    // Update loading text progressively
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _loadingText = "Preparing your flashcards...";
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _loadingText = "Almost ready...";
        });
      }
    });

    // Transition to main content after minimum time
    Future.delayed(widget.minimumDisplayTime, () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showContent ? widget.child : _buildSplashScreen();
  }

  Widget _buildSplashScreen() {
    // Get theme from ThemeProvider and system brightness
    final themeProvider = context.watch<ThemeProvider>();
    final systemBrightness = MediaQuery.of(context).platformBrightness;
    
    bool isDark;
    switch (themeProvider.themeMode) {
      case ThemeMode.dark:
        isDark = true;
        break;
      case ThemeMode.light:
        isDark = false;
        break;
      case ThemeMode.system:
      default:
        isDark = systemBrightness == Brightness.dark;
        break;
    }
    
    final splashImage = isDark ? 'taal-trek-splash-dark.png' : 'taal-trek-splash.png';
    print('🔍 LoadingView: Using splash image: $splashImage (isDark: $isDark, themeMode: ${themeProvider.themeMode}, systemBrightness: $systemBrightness)');
    
    return Material(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: isDark ? Colors.black : Colors.white,
        child: Stack(
          children: [
            // Centered splash image
            Center(
              child: Image.asset(
                'assets/images/$splashImage',
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            
            // Loading indicator overlay at bottom
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Progress indicator
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.white : const Color(0xFF007AFF),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Loading text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _loadingText,
                      key: ValueKey(_loadingText),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
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
} 