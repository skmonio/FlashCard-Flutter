import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class HelpCenterView extends StatelessWidget {
  const HelpCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Help Center'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Icon(section.icon, color: section.iconColor),
              title: Text(
                section.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(section.subtitle),
              initiallyExpanded: index == 0,
              children: [
                if (section.asset != null)
                  HelpImagePreview(
                    asset: section.asset!,
                    caption: section.assetCaption,
                  ),
                if (section.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    section.description!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...section.items.map((item) => _HelpItemTile(item: item)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<HelpSection> _buildSections() {
    return [
      HelpSection(
        title: 'Getting Around',
        subtitle: 'Home screen, navigation, and quick actions',
        icon: Icons.dashboard_customize,
        iconColor: Colors.indigo,
        asset: 'assets/images/taal-trek-splash-optimized.png',
        assetCaption: 'Home screen preview – tap the bottom tabs to switch modes.',
        description:
            'Use the bottom navigation bar to jump between Study, Friends, Leaderboard, and Stats. The floating buttons on the home screen help you add cards quickly or launch a study session.',
        items: [
          HelpItem(
            title: 'Bottom Navigation',
            points: [
              'Stats: track XP, streaks, and mastery progress.',
              'Friends: manage requests, search users, and view profiles.',
              'Leaderboard: compare XP across global, weekly, monthly, and friends tabs.',
            ],
          ),
          HelpItem(
            title: 'Quick Actions',
            points: [
              'Use the “+” button to add new cards or import decks.',
              'Shuffle launches a single-question mixed challenge – perfect for quick practice.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'Creating & Editing Cards',
        subtitle: 'Add words manually, scan text, and organize decks',
        icon: Icons.post_add,
        iconColor: Colors.teal,
        items: [
          HelpItem(
            title: 'Add New Cards',
            points: [
              'Tap “Create Card” to add a word manually with definition, example, and grammar fields.',
              'Use “Scan Text” to capture vocabulary from books or signs (OCR happens on-device).',
              'Import CSV files or deck packs from Settings → Import/Export.',
            ],
          ),
          HelpItem(
            title: 'Editing & Enhancing',
            points: [
              'Tap any card to edit details, add example sentences, or attach notes.',
              'Assign cards to multiple decks and categories for tailored study sets.',
              'Use the “Scan for Exercises” option to auto-generate practice for each word.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'Study Modes & Games',
        subtitle: 'Choose the right exercise for your goal',
        icon: Icons.sports_esports,
        iconColor: Colors.deepPurple,
        description: 'Each mode awards XP and tracks wrong attempts differently. Mix modes to keep study fresh.',
        items: [
          HelpItem(
            title: 'Multiple Choice',
            points: [
              'Great for recognition. Wrong answers reduce XP for that round but not HP.',
              'Hints and elimination help you learn without getting stuck.',
            ],
          ),
          HelpItem(
            title: 'True or False',
            points: [
              'Quick knowledge checks with immediate feedback.',
              'Perfect when you only have a minute to practice.',
            ],
          ),
          HelpItem(
            title: 'Word Scramble & Writing',
            points: [
              'Improve spelling by rearranging letters or typing the answer.',
              'Wrong letters shake the card; five mistakes reveal the solution (0 XP).',
            ],
          ),
          HelpItem(
            title: 'Memory Game',
            points: [
              'Turn cards to find pairs. Track wrong matches and earn partial XP when you succeed.',
              'Best with 6–12 cards for a single session.',
            ],
          ),
          HelpItem(
            title: 'Shuffle Mode',
            points: [
              'Continuous run of single-question challenges across all modes.',
              'One wrong answer ends the streak – perfect for testing mastery.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'XP, Levels & HP',
        subtitle: 'How progression and health work together',
        icon: Icons.favorite,
        iconColor: Colors.redAccent,
        items: [
          HelpItem(
            title: 'Earning XP',
            points: [
              'Gain XP for every correct answer. Wrong attempts reduce rewards but never below 0.',
              'Hit streaks boost XP; hints or multiple mistakes lower it.',
            ],
          ),
          HelpItem(
            title: 'Understanding HP',
            points: [
              'Each card has 10 HP per day. Every study attempt uses 1 HP.',
              'HP heals by +1 each hour after you stop using that card (up to the daily limit).',
              'If HP is 0, the card rests until it recovers – perfect time to review other decks.',
            ],
          ),
          HelpItem(
            title: 'Levels & Mastery',
            points: [
              'XP levels unlock achievements and streak bonuses.',
              'Word mastery scores show how confident you are with each card.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'Social & Leaderboards',
        subtitle: 'Connect with friends and compete together',
        icon: Icons.people_alt,
        iconColor: Colors.blueAccent,
        items: [
          HelpItem(
            title: 'Friends',
            points: [
              'Search usernames in the Friends tab, send requests, and accept invites.',
              'View a friend’s decks, stats, and recent activity for study inspiration.',
            ],
          ),
          HelpItem(
            title: 'Leaderboards',
            points: [
              'Check global, weekly, monthly, and friends leaderboards.',
              'Your position updates after each sync. No friends yet? Invite some to fill the list.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'Tracking Progress',
        subtitle: 'Stay motivated with stats and streaks',
        icon: Icons.trending_up,
        iconColor: Colors.orange,
        items: [
          HelpItem(
            title: 'Stats Dashboard',
            points: [
              'View daily study time, XP gained, cards reviewed, and accuracy.',
              'Streak tracker keeps you consistent – missing a day resets it.',
            ],
          ),
          HelpItem(
            title: 'Word Insights',
            points: [
              'Tap any word to open detailed stats, including mastery level and review history.',
              'Use filters to target “Needs Review” or “New” cards.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'Customization & Settings',
        subtitle: 'Make the app fit your study style',
        icon: Icons.tune,
        iconColor: Colors.green,
        items: [
          HelpItem(
            title: 'Themes & Sounds',
            points: [
              'Switch between light, dark, or system mode for comfort.',
              'Adjust sound effects or disable haptics if you prefer silent study.',
            ],
          ),
          HelpItem(
            title: 'Language Options',
            points: [
              'Choose your learning language and translation language in Settings.',
              'Supports multiple native languages – great for multilingual learners.',
            ],
          ),
          HelpItem(
            title: 'Import & Export',
            points: [
              'Backup decks or share them with friends via CSV export.',
              'Import shared decks or community packs to expand your vocabulary.',
            ],
          ),
        ],
      ),
      HelpSection(
        title: 'Tips & Troubleshooting',
        subtitle: 'Quick fixes for common questions',
        icon: Icons.lightbulb,
        iconColor: Colors.amber,
        items: [
          HelpItem(
            title: 'Study Tips',
            points: [
              'Mix study modes daily to reinforce memory from different angles.',
              'Use Shuffle mode when you feel confident; it surfaces tricky words quickly.',
            ],
          ),
          HelpItem(
            title: 'Troubleshooting',
            points: [
              'If OCR fails, re-scan with better lighting or adjust the focus.',
              'Offline? You can still review existing cards. Sync resumes when online.',
              'Need help? Contact support@taaltrek.com from the Support page.',
            ],
          ),
        ],
      ),
    ];
  }
}

class HelpSection {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String? description;
  final List<HelpItem> items;
  final String? asset;
  final String? assetCaption;

  const HelpSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.description,
    required this.items,
    this.asset,
    this.assetCaption,
  });
}

class HelpItem {
  final String title;
  final List<String> points;
  final String? asset;
  final String? assetCaption;

  const HelpItem({
    required this.title,
    required this.points,
    this.asset,
    this.assetCaption,
  });
}

class _HelpItemTile extends StatelessWidget {
  final HelpItem item;

  const _HelpItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          ...item.points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item.asset != null) ...[
            const SizedBox(height: 8),
            HelpImagePreview(
              asset: item.asset!,
              caption: item.assetCaption,
            ),
          ],
        ],
      ),
    );
  }
}

class HelpImagePreview extends StatelessWidget {
  final String asset;
  final String? caption;

  const HelpImagePreview({super.key, required this.asset, this.caption});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _doesAssetExist(asset),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || snapshot.data != true) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                height: 180,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(
                caption!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<bool> _doesAssetExist(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }
}

