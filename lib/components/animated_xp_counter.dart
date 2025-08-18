import 'package:flutter/material.dart';
import 'dart:async';

class AnimatedXpCounter extends StatefulWidget {
  final int xpGained;
  final Duration duration;
  final TextStyle? style;
  final Color? color;

  const AnimatedXpCounter({
    super.key,
    required this.xpGained,
    this.duration = const Duration(milliseconds: 1500),
    this.style,
    this.color,
  });

  @override
  State<AnimatedXpCounter> createState() => _AnimatedXpCounterState();
}

class _AnimatedXpCounterState extends State<AnimatedXpCounter>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  int _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = IntTween(
      begin: 0,
      end: widget.xpGained,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _animation.addListener(() {
      setState(() {
        _currentValue = _animation.value;
      });
    });

    // Start animation after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '+$_currentValue XP',
      style: widget.style ?? TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: widget.color ?? Colors.amber,
      ),
    );
  }
}
