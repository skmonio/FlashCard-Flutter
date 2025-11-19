import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class CachedProfileAvatar extends StatelessWidget {
  const CachedProfileAvatar({
    super.key,
    required this.size,
    this.base64Image,
    required this.fallbackIcon,
    required this.backgroundColor,
    required this.iconColor,
    this.semanticLabel,
  });

  final double size;
  final String? base64Image;
  final IconData fallbackIcon;
  final Color backgroundColor;
  final Color iconColor;
  final String? semanticLabel;

  static final Map<String, Uint8List> _imageCache = {};

  @override
  Widget build(BuildContext context) {
    final Semantics semanticsWrapper = Semantics(
      label: semanticLabel,
      image: base64Image != null,
      child: _buildAvatar(context),
    );
    return semanticsWrapper;
  }

  Widget _buildAvatar(BuildContext context) {
    final double iconSize = size * 0.55;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final Color adaptiveBackground = highContrast
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
        : backgroundColor;
    final Color adaptiveIconColor = highContrast
        ? Theme.of(context).colorScheme.primary
        : iconColor;

    if (base64Image == null || base64Image!.isEmpty) {
      return _buildFallback(adaptiveBackground, adaptiveIconColor, iconSize);
    }

    final bytes = _getImageBytes(base64Image!);
    if (bytes == null) {
      return _buildFallback(adaptiveBackground, adaptiveIconColor, iconSize);
    }

    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _buildFallback(adaptiveBackground, adaptiveIconColor, iconSize),
      ),
    );
  }

  Widget _buildFallback(Color background, Color iconColor, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
      ),
      child: Icon(
        fallbackIcon,
        color: iconColor,
        size: iconSize,
      ),
    );
  }

  Uint8List? _getImageBytes(String data) {
    if (_imageCache.containsKey(data)) {
      return _imageCache[data];
    }

    try {
      final decoded = base64Decode(data);
      _imageCache[data] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }
}
