import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Completion rate, streaks and time per category (FR-17, version 2).
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.tabInsights)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
