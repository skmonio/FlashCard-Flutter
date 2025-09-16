import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/data_sync_service.dart';
import '../services/supabase_service.dart';

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
  bool _isSyncing = false;
  double _syncProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _startLoadingSequence();
  }

  void _startLoadingSequence() async {
    // Check if user is authenticated and sync data if needed
    final isAuthenticated = SupabaseService.instance.isAuthenticated;
    
    if (isAuthenticated) {
      await _syncData();
    } else {
      // If not authenticated, proceed with normal loading sequence
      _proceedWithNormalLoading();
    }
    
    // Wait for the isReadyCheck to complete
    if (widget.isReadyCheck != null) {
      await widget.isReadyCheck!();
    }
    
    // Transition to main content after minimum time
    Future.delayed(widget.minimumDisplayTime, () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
      }
    });
  }

  Future<void> _syncData() async {
    if (!mounted) return;
    
    setState(() {
      _isSyncing = true;
      _loadingText = "Syncing your data...";
      _syncProgress = 0.0;
    });

    try {
      // Simulate progress updates during sync
      _updateSyncProgress(0.2, "Downloading your data...");
      await Future.delayed(const Duration(milliseconds: 300));
      
      _updateSyncProgress(0.4, "Syncing flashcards...");
      await DataSyncService.syncFlashcards();
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateSyncProgress(0.6, "Syncing decks...");
      await DataSyncService.syncDecks();
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateSyncProgress(0.8, "Syncing user profile...");
      await DataSyncService.syncUserProfile();
      await Future.delayed(const Duration(milliseconds: 200));
      
      _updateSyncProgress(1.0, "Sync complete!");
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      print('Error during data sync: $e');
      if (mounted) {
        setState(() {
          _loadingText = "Sync completed with minor issues";
        });
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _loadingText = "Almost ready...";
      });
      
      // Wait a bit more before showing content
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (mounted) {
        setState(() {
          _showContent = true;
        });
      }
    }
  }

  void _updateSyncProgress(double progress, String text) {
    if (mounted) {
      setState(() {
        _syncProgress = progress;
        _loadingText = text;
      });
    }
  }

  void _proceedWithNormalLoading() {
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
                  if (_isSyncing) ...[
                    // Show progress bar when syncing
                    Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _syncProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: isDark ? Colors.white : const Color(0xFF007AFF),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_syncProgress * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else ...[
                    // Show circular progress when not syncing
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : const Color(0xFF007AFF),
                      ),
                    ),
                  ],
                  
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