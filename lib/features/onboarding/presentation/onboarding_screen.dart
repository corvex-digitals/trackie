import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/reminder_health_panel.dart';

/// First launch (section 8): language and calendar, then the permissions
/// reminders depend on, with battery guidance on Android. Sign-in is a
/// version 2 feature (FR-02).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    setState(() => _page = page);
    _pages.animateToPage(page,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final user = ref.read(userProvider).value;
    await ref.read(categoryRepositoryProvider).seedDefaults(user?.language ?? 'en');
    await ref.read(settingsRepositoryProvider).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(userProvider).value;
    final settings = ref.read(settingsRepositoryProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget option(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: selected
              ? FilledButton(onPressed: onTap, child: Text(label))
              : OutlinedButton(onPressed: onTap, child: Text(label)),
        );

    final welcome = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.event_note, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(l.onboardingWelcomeTitle,
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(l.onboardingWelcomeBody, textAlign: TextAlign.center),
        const SizedBox(height: 32),
        Text(l.settingLanguage, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        option('English', user.language == 'en', () => settings.setLanguage('en')),
        option('አማርኛ', user.language == 'am', () => settings.setLanguage('am')),
        const SizedBox(height: 16),
        Text(l.settingCalendar, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        option(l.calendarGregorian, user.calendarType == 'gregorian',
            () => settings.setCalendarType('gregorian')),
        option(l.calendarEthiopian, user.calendarType == 'ethiopian',
            () => settings.setCalendarType('ethiopian')),
      ],
    );

    final reminders = ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Icon(Icons.notifications_active_outlined,
            size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            Text(l.onboardingRemindersTitle,
                textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(l.onboardingRemindersBody, textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 16),
        const ReminderHealthPanel(),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [welcome, reminders],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(onPressed: () => _go(0), child: Text(l.back)),
                  const Spacer(),
                  FilledButton(
                    onPressed: _finishing
                        ? null
                        : _page == 0
                            ? () => _go(1)
                            : _finish,
                    child: Text(_page == 0 ? l.continueButton : l.getStarted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
