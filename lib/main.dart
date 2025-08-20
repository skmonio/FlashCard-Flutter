import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/flashcard_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/bubble_word_provider.dart';
import 'providers/dutch_word_exercise_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/dutch_grammar_provider.dart';
import 'providers/store_provider.dart';
import 'providers/phrase_provider.dart';
import 'services/performance_service.dart';
import 'views/app_initialization_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize performance service for battery and memory optimization
  PerformanceService().initialize();
  
  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
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
        ChangeNotifierProvider(create: (context) => DutchGrammarProvider()),
        ChangeNotifierProvider(create: (context) => StoreProvider()),
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
          // Update system UI overlay style based on theme
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final isDark = themeProvider.themeMode == ThemeMode.dark || 
                          (themeProvider.themeMode == ThemeMode.system && 
                           MediaQuery.of(context).platformBrightness == Brightness.dark);
            
            SystemChrome.setSystemUIOverlayStyle(
              isDark 
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                  ),
            );
          });
          
          return MaterialApp(
            title: 'Taal Trek',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF007AFF), // iOS blue
                brightness: Brightness.light,
              ),
              useMaterial3: true,
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
