import 'package:flutter/material.dart';
import '../models/flash_card.dart';
import '../models/learning_mastery.dart';
import '../services/xp_service.dart';
import '../services/sound_manager.dart';

class UnifiedEndScreen extends StatefulWidget {
  final List<FlashCard> studiedWords;
  final Map<String, int> xpGainedPerWord;
  final Map<String, LearningMastery> wordMastery;
  final VoidCallback? onStudyAgain;
  final VoidCallback? onDone;
  final VoidCallback? onShuffle;
  final String title;
  final bool showSwipeToReview;

  const UnifiedEndScreen({
    super.key,
    required this.studiedWords,
    required this.xpGainedPerWord,
    required this.wordMastery,
    this.onStudyAgain,
    this.onDone,
    this.onShuffle,
    this.title = 'Session Complete',
    this.showSwipeToReview = false,
  });

  @override
  State<UnifiedEndScreen> createState() => _UnifiedEndScreenState();
}

class _UnifiedEndScreenState extends State<UnifiedEndScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _progressController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideUpAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Play complete sound when end screen loads
    SoundManager().playCompleteSound();
    
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOut,
    ));
    _slideUpAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    ));
    _mainController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _progressController.forward();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final xpService = XpService();
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
            // Header with back button and title
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Back button (top left) - always show
                    IconButton(
                      onPressed: () {
                        // Use the onDone callback if available, otherwise just pop
                        if (widget.onDone != null) {
                          widget.onDone!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios),
                      iconSize: 20,
                    ),
                    const Spacer(),
                    // Title in the middle
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Home button (top right)
                    IconButton(
                      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                      icon: const Icon(Icons.home),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ),
            
            // Content - Make it scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    // Summary with animations
                    SlideTransition(
                      position: _slideUpAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Session Summary',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.studiedWords.length} words studied',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 4),
                              // Check if user got any XP (any correct answers)
                              if (widget.xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp) > 0) ...[
                                AnimatedBuilder(
                                  animation: _scaleAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _scaleAnimation.value,
                                      child: Text(
                                        '${widget.xpGainedPerWord.values.fold(0, (sum, xp) => sum + xp)} total XP gained',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ] else ...[
                                // Motivation for zero correct answers
                                AnimatedBuilder(
                                  animation: _scaleAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _scaleAnimation.value,
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.emoji_emotions,
                                            size: 32,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Keep practicing!',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Every attempt makes you stronger',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Colors.orange.withValues(alpha: 0.8),
                                              fontStyle: FontStyle.italic,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Word list with staggered animations
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.studiedWords.length,
                      itemBuilder: (context, index) {
                        final word = widget.studiedWords[index];
                        final xpGained = widget.xpGainedPerWord[word.id] ?? 0;
                        final mastery = widget.wordMastery[word.id];
                        
                        if (mastery == null) return const SizedBox.shrink();
                        
                        final level = mastery.rpgWordLevel;
                        final progress = mastery.rpgLevelProgress;
                        final xpNeeded = mastery.xpNeededForNextLevel;
                        
                        // Staggered animation for each card
                        final cardAnimation = Tween<double>(
                          begin: 0.0,
                          end: 1.0,
                        ).animate(CurvedAnimation(
                          parent: _mainController,
                          curve: Interval(
                            (index * 0.1).clamp(0.0, 1.0),
                            ((index + 1) * 0.1).clamp(0.0, 1.0),
                            curve: Curves.easeOut,
                          ),
                        ));
                        
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _mainController,
                            curve: Interval(
                              (index * 0.1).clamp(0.0, 1.0),
                              ((index + 1) * 0.1).clamp(0.0, 1.0),
                              curve: Curves.easeOutCubic,
                            ),
                          )),
                          child: FadeTransition(
                            opacity: cardAnimation,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Word and level
                                    Row(
                                      children: [
                                        Text(
                                          xpService.getLevelIcon(level),
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                word.word,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'Level ${level.level} - ${level.title}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Show XP badge for both correct and incorrect answers
                                        AnimatedBuilder(
                                          animation: _scaleAnimation,
                                          builder: (context, child) {
                                            return Transform.scale(
                                              scale: _scaleAnimation.value,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: xpGained > 0 
                                                      ? Colors.green.withValues(alpha: 0.1)
                                                      : Colors.orange.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  xpGained > 0 ? '+$xpGained XP' : '0 XP',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: xpGained > 0 ? Colors.green : Colors.orange,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Animated progress bar
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${mastery.currentXPWithDecay} XP',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (xpNeeded > 0)
                                              Text(
                                                '$xpNeeded XP to next level',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        AnimatedBuilder(
                                          animation: _progressController,
                                          builder: (context, child) {
                                            final animatedProgress = Tween<double>(
                                              begin: 0.0,
                                              end: progress,
                                            ).animate(CurvedAnimation(
                                              parent: _progressController,
                                              curve: Curves.easeOutCubic,
                                            ));
                                            
                                            return LinearProgressIndicator(
                                              value: animatedProgress.value,
                                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                Color(xpService.getProgressBarColor(progress)),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    
                                    // HP Information
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          word.isDefeated 
                                              ? Icons.block 
                                              : Icons.favorite,
                                          size: 16,
                                          color: word.isDefeated 
                                              ? Colors.grey[600]
                                              : word.hpPercentage > 0.6 
                                                  ? Colors.green[600]
                                                  : word.hpPercentage > 0.3 
                                                      ? Colors.orange[600]
                                                      : Colors.red[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'HP: ${word.currentHP}/${word.maxHP}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: word.isDefeated 
                                                ? Colors.grey[600]
                                                : word.hpPercentage > 0.6 
                                                    ? Colors.green[600]
                                                    : word.hpPercentage > 0.3 
                                                        ? Colors.orange[600]
                                                        : Colors.red[600],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          word.isDefeated
                                              ? 'Defeated'
                                              : word.hpStatus,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: word.isDefeated 
                                                ? Colors.grey[600]
                                                : word.hpPercentage > 0.6 
                                                    ? Colors.green[600]
                                                    : word.hpPercentage > 0.3 
                                                        ? Colors.orange[600]
                                                        : Colors.red[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Motivational message
                                    if (xpGained > 0) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        xpService.getMotivationalMessage(progress),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20), // Bottom padding
                  ],
                ),
              ),
            ),
            
            // Animated footer with action buttons
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _mainController,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: _fadeInAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onStudyAgain,
                          child: const Text('Study Again'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onShuffle ?? widget.onDone,
                          child: Text(widget.onShuffle != null ? 'Shuffle' : 'Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
