import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../tasks/domain/scheduling.dart';
import 'reminder_health_panel.dart';

/// Settings (FR-19, FR-20, NFR-01, NFR-08).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(userProvider).value;
    final settings = ref.read(settingsRepositoryProvider);
    final health = ref.watch(reminderHealthProvider).value;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.tabSettings)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String reminderLabel(int m) => m == 0 ? l.reminderAtStart : l.reminderBefore(m);

    return Scaffold(
      appBar: AppBar(title: Text(l.tabSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionTitle(l.sectionReminders),
          if (health != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(health.allGood ? l.remindersReady : l.remindersAttention),
            ),
          const ReminderHealthPanel(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l.settingDefaultReminder),
            subtitle: Text(reminderLabel(user.defaultReminderOffset)),
            onTap: () async {
              final picked = await showDialog<int>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text(l.settingDefaultReminder),
                  children: [
                    RadioGroup<int>(
                      groupValue: user.defaultReminderOffset,
                      onChanged: (v) => Navigator.pop(context, v),
                      child: Column(children: [
                        for (final m in SchedulingPolicy.reminderChoices)
                          RadioListTile<int>(value: m, title: Text(reminderLabel(m))),
                      ]),
                    ),
                  ],
                ),
              );
              if (picked != null) await settings.setDefaultReminderOffset(picked);
            },
          ),
          const Divider(),
          _SectionTitle(l.sectionGeneral),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(l.categoriesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => CategoriesScreen.open(context),
          ),
          _RadioSection<String>(
            title: l.settingLanguage,
            value: user.language,
            options: const {'en': 'English', 'am': 'አማርኛ'},
            onChanged: settings.setLanguage,
          ),
          _RadioSection<String>(
            title: l.settingCalendar,
            value: user.calendarType,
            options: {
              'gregorian': l.calendarGregorian,
              'ethiopian': l.calendarEthiopian,
            },
            onChanged: settings.setCalendarType,
          ),
          _RadioSection<String>(
            title: l.settingTheme,
            value: user.theme,
            options: {
              'system': l.themeSystem,
              'light': l.themeLight,
              'dark': l.themeDark,
            },
            onChanged: settings.setTheme,
          ),
          const Divider(),
          _SectionTitle(l.sectionData),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text(l.deleteAllData),
            subtitle: Text(l.deleteAllDataBody),
            onTap: () => _confirmDeleteAll(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAllData),
        content: Text(l.deleteAllDataBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deleteEverything),
          ),
        ],
      ),
    );
    // The app returns to onboarding once the fresh profile appears.
    if (ok == true) await ref.read(servicesProvider).deleteAllData();
  }
}

class _RadioSection<T> extends StatelessWidget {
  const _RadioSection({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final Future<void> Function(T) onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
          RadioGroup<T>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            child: Column(children: [
              for (final e in options.entries)
                RadioListTile<T>(value: e.key, title: Text(e.value), dense: true),
            ]),
          ),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
