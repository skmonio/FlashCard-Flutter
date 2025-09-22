import 'package:flutter/material.dart';

class AvatarUtils {
  static const Map<String, IconData> avatarIcons = {
    'person.crop.circle.fill': Icons.person,
    'person.crop.circle': Icons.person_outline,
    'person.fill': Icons.person,
    'person': Icons.person_outline,
    'person.2.fill': Icons.group,
    'person.2': Icons.group_outlined,
    'graduationcap.fill': Icons.school,
    'graduationcap': Icons.school_outlined,
    'book.fill': Icons.book,
    'book': Icons.book_outlined,
    'brain.head.profile': Icons.psychology,
    'brain': Icons.psychology_outlined,
  };

  static IconData getAvatarIcon(String avatar) {
    return avatarIcons[avatar] ?? Icons.person;
  }
}
