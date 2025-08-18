import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/theme_provider.dart';
import '../services/sample_data_service.dart';
import 'home_view.dart';
import 'cards_view.dart';
import 'store_view.dart';
import 'settings_view.dart';
import '../components/bottom_navigation_view.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _selectedTabIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Initialize the providers when the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize theme provider
      final themeProvider = context.read<ThemeProvider>();
      await themeProvider.initialize();
      
      // Initialize flashcard provider
      final provider = context.read<FlashcardProvider>();
      await provider.initialize();
      
      print('Initial cards count: ${provider.cards.length}');
      print('Initial decks count: ${provider.decks.length}');
      
      // Force load sample data for testing
      print('Loading sample data...');
      await SampleDataService.addSampleData(provider);
      
      print('After loading - Cards count: ${provider.cards.length}');
      print('After loading - Decks count: ${provider.decks.length}');
      
      // Force refresh the UI
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        children: const [
          HomeView(),
          CardsView(),
          StoreView(),
          SettingsView(),
        ],
      ),
      bottomNavigationBar: BottomNavigationView(
        selectedTabIndex: _selectedTabIndex,
        onTabChanged: _onTabChanged,
      ),
    );
  }
} 