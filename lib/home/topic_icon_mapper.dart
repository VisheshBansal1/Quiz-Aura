import 'package:flutter/material.dart';

class TopicIconMapper {
  static final Map<String, IconData> _iconMap = {
    'account_tree': Icons.account_tree,
    'flutter_dash': Icons.flutter_dash,
    'code': Icons.code,
    'psychology': Icons.psychology,
    'quiz': Icons.quiz,
  };

  static IconData fromString(String? name) {
    if (name == null || name.trim().isEmpty) {
      return Icons.quiz;
    }

    final key = name.trim().toLowerCase();

    return _iconMap[key] ?? Icons.quiz;
  }
}
