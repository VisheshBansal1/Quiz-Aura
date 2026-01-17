import 'package:flutter/material.dart';

class TopicIconMapper {
  static IconData fromString(String name) {
    switch (name) {
      case 'account_tree':
        return Icons.account_tree;
      case 'flutter_dash':
        return Icons.flutter_dash;
      case 'code':
        return Icons.code;
      case 'psychology':
        return Icons.psychology;
      default:
        return Icons.quiz;
    }
  }
}
