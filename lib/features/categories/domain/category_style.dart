import 'package:flutter/material.dart';

/// The colours and icons a category can use (FR-19). Icons are stored by key
/// so the data stays platform-neutral and can sync.
abstract final class CategoryStyle {
  static const colors = <int>[
    0xFF2E7D6B, // green
    0xFF1E88E5, // blue
    0xFF8E24AA, // purple
    0xFFE53935, // red
    0xFFFB8C00, // orange
    0xFFF9A825, // amber
    0xFF6D4C41, // brown
    0xFF546E7A, // blue grey
    0xFFD81B60, // pink
    0xFF00897B, // teal
  ];

  static const icons = <String, IconData>{
    'work': Icons.work_outline,
    'study': Icons.school_outlined,
    'health': Icons.favorite_outline,
    'fitness': Icons.fitness_center,
    'personal': Icons.person_outline,
    'home': Icons.home_outlined,
    'family': Icons.groups_outlined,
    'faith': Icons.self_improvement,
    'shopping': Icons.shopping_bag_outlined,
    'finance': Icons.account_balance_wallet_outlined,
    'travel': Icons.directions_bus_outlined,
    'other': Icons.label_outline,
  };

  static IconData icon(String? key) => icons[key] ?? Icons.label_outline;
}

/// Starter categories created at the end of onboarding.
class DefaultCategory {
  const DefaultCategory(this.en, this.am, this.color, this.icon);
  final String en;
  final String am;
  final int color;
  final String icon;

  String name(String language) => language == 'am' ? am : en;

  static const all = [
    DefaultCategory('Work', 'ሥራ', 0xFF1E88E5, 'work'),
    DefaultCategory('Study', 'ትምህርት', 0xFF8E24AA, 'study'),
    DefaultCategory('Health', 'ጤና', 0xFF2E7D6B, 'health'),
    DefaultCategory('Personal', 'የግል', 0xFFFB8C00, 'personal'),
  ];
}
