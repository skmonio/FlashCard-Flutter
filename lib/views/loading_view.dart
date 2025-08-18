import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sound_manager.dart';

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

class _LoadingViewState extends State<LoadingView>
    with TickerProviderStateMixin {
  bool _showContent = false;
  double _opacity = 1.0; // Start visible immediately
  double _progressPulse = 1.0;
  String _loadingText = "Loading your Dutch learning journey...";
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _startLoadingSequence();
  }

  @override
  void dispose() {
    _disposed = true;
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startLoadingSequence() {
    // Start pulsing animation for progress indicator immediately
    if (mounted && !_disposed) {
      _pulseController.repeat(reverse: true);
    }

    // Update loading text progressively
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_disposed) {
        setState(() {
          _loadingText = "Preparing your flashcards...";
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && !_disposed) {
        setState(() {
          _loadingText = "Almost ready...";
        });
      }
    });

    // Check for readiness and transition to main content
    _checkAndTransition();
  }

  void _checkAndTransition() {
    final startTime = DateTime.now();
    
    Future.doWhile(() async {
      if (_disposed) return false;
      
      final elapsed = DateTime.now().difference(startTime);
      final minimumTimeMet = elapsed >= widget.minimumDisplayTime;
      
      bool isReady = true;
      if (widget.isReadyCheck != null) {
        isReady = await widget.isReadyCheck!();
      }

      if (minimumTimeMet && isReady) {
        if (!_disposed) {
          // Add haptic feedback for completion
          HapticFeedback.lightImpact();
          
          // Play begin sound as splash screen fades away
          SoundManager().playBeginSound();
          
          // Transition to main content
          setState(() {
            _showContent = true;
          });
        }
        return false; // Stop the loop
      }
      
      await Future.delayed(const Duration(milliseconds: 50));
      return !_disposed; // Continue the loop if not disposed
    });
  }

  @override
  Widget build(BuildContext context) {
    return _showContent ? widget.child : _buildSplashScreen();
  }

  Widget _buildSplashScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final splashImage = isDark ? 'taal-trek-splash-dark.png' : 'taal-trek-splash.png';
    
    return Material(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: isDark ? Colors.black : Colors.white,
        child: Stack(
          children: [
            // Centered splash image
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _opacity,
                child: Image.asset(
                  'assets/images/$splashImage',
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            
            // Loading indicator overlay at bottom
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _opacity * 0.8,
                child: Column(
                  children: [
                    // Pulsing progress indicator
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.2 + (0.2 * _pulseController.value),
                          child: const CircularProgressIndicator(),
                        );
                      },
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
            ),
          ],
        ),
      ),
    );
  }
} 