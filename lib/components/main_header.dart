import 'package:flutter/material.dart';
import '../views/user_profile_view.dart';

class MainHeader extends StatelessWidget {
  final String? title;
  final Widget? leftAction;
  final Widget? rightAction;
  final VoidCallback? onProfileTap;

  const MainHeader({
    super.key,
    this.title,
    this.leftAction,
    this.rightAction,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: kToolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Centered title - always in the center regardless of other elements
            Center(
              child: Text(
                title ?? 'Taal Trek',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            
            // Left side - optional action or placeholder
            if (leftAction != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: leftAction!,
              ),
            
            // Right side - Profile button or optional action
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: rightAction ?? IconButton(
                icon: const Icon(Icons.person, color: Colors.black),
                onPressed: onProfileTap ?? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserProfileView(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
