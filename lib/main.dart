import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/flashcard_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/bubble_word_provider.dart';
import 'providers/dutch_word_exercise_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/dutch_grammar_provider.dart';
import 'providers/store_provider.dart';
import 'views/main_navigation_view.dart';
import 'views/loading_view.dart';
import 'services/haptic_service.dart';

void main() async {
  // Ensure Flutter binding is initialized before accessing platform services
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize haptic service
  await HapticService().initialize();
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
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
            home: LoadingView(
              minimumDisplayTime: const Duration(milliseconds: 200),
              isReadyCheck: () async {
                // Add a timeout to prevent infinite loading
                await Future.delayed(const Duration(milliseconds: 500));
                return true;
              },
              child: const MainNavigationView(),
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
