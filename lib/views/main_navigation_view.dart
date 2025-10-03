import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../providers/theme_provider.dart';
import '../services/sample_data_service.dart';
import 'home_view.dart';
import 'cards_view.dart';
import 'settings_view.dart';
import '../components/bottom_navigation_view.dart';
import '../components/main_header.dart';
import '../components/universal_add_button.dart';

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
      // Only initialize if not already done by AppInitializationView
      final provider = context.read<FlashcardProvider>();
      
      // Check if provider is already initialized (from AppInitializationView)
      if (provider.cards.isEmpty) {
        await provider.initialize();
      }
      
      // Check if user wants sample data (only show on first launch)
      if (await SampleDataService.shouldShowSampleDataPrompt()) {
        await SampleDataService.showSampleDataPrompt(context, provider);
      }
      
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
      body: Column(
        children: [
          // Fixed Header
          const MainHeader(),
          
          // Page Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              children: const [
                HomeView(),
                CardsView(),
                SettingsView(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationView(
        selectedTabIndex: _selectedTabIndex,
        onTabChanged: _onTabChanged,
      ),
    );
  }


} 