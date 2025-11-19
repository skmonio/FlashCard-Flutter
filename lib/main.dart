import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/flashcard_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/sound_provider.dart';
import 'providers/bubble_word_provider.dart';
import 'providers/dutch_word_exercise_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/translation_language_provider.dart';

import 'providers/phrase_provider.dart';
import 'services/performance_service.dart';
import 'services/supabase_service.dart';
import 'services/deep_link_service.dart';
import 'utils/global_navigator.dart';
import 'utils/status_bar_utils.dart';
import 'views/app_initialization_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    print('✅ Supabase initialized successfully');
    
    // Initialize deep link handling
    DeepLinkService.initialize();
    print('✅ Deep link service initialized');
  } catch (e) {
    print('❌ Failed to initialize Supabase: $e');
    // App can still run without Supabase for now
  }
  
  // Initialize performance service for battery and memory optimization
  PerformanceService().initialize();
  
  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set initial status bar to light mode (black text/icons)
  StatusBarUtils.setLightStatusBar();
  
  runApp(const FlashcardApp());
}

class FlashcardApp extends StatelessWidget {
  const FlashcardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => FlashcardProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => SoundProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final provider = TranslationLanguageProvider();
            provider.initialize(); // Initialize the provider
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (context) => BubbleWordProvider()),
        ChangeNotifierProvider(
          create: (context) {
            final provider = DutchWordExerciseProvider();
            provider.initialize(); // Initialize the provider
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final provider = UserProfileProvider();
            provider.initialize(); // Initialize the provider
            return provider;
          },
        ),

        ChangeNotifierProvider(
          create: (context) {
            final provider = PhraseProvider();
            provider.loadPhrases(); // Initialize the provider
            return provider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Update system UI overlay style based on theme immediately
          final isDark = themeProvider.themeMode == ThemeMode.dark || 
                        (themeProvider.themeMode == ThemeMode.system && 
                         MediaQuery.of(context).platformBrightness == Brightness.dark);
          
          // Use the utility function for consistent status bar management
          StatusBarUtils.updateStatusBar(context, isDark: isDark);
          
          return MaterialApp(
            title: 'Taal Trek',
            navigatorKey: GlobalNavigator.navigatorKey,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF007AFF), // iOS blue
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
                  TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                  TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
                },
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF007AFF),
                    brightness: Brightness.light,
                  ).onSurface,
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF007AFF),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
                  TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                  TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
                },
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF007AFF),
                    brightness: Brightness.dark,
                  ).onSurface,
                ),
              ),
            ),
            home: const AppInitializationView(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
