import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'loading_view.dart';
import 'main_navigation_view.dart';

class AppInitializationView extends StatefulWidget {
  const AppInitializationView({super.key});

  @override
  State<AppInitializationView> createState() => _AppInitializationViewState();
}

class _AppInitializationViewState extends State<AppInitializationView> {
  bool _themeInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTheme();
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

  @override
  Widget build(BuildContext context) {
    if (!_themeInitialized) {
      // Show a basic splash screen while theme loads
      final systemBrightness = MediaQuery.of(context).platformBrightness;
      final isDark = systemBrightness == Brightness.dark;
      
      return Material(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: isDark ? Colors.black : Colors.white,
          child: Center(
            child: Image.asset(
              isDark ? 'assets/images/taal-trek-splash-dark.png' : 'assets/images/taal-trek-splash.png',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      );
    }

    // Once theme is initialized, show the normal loading view
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
