import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/date_display.dart';
import '../../../core/utils/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/presentation/task_editor_screen.dart';
import '../../today/presentation/day_timeline.dart';
import '../../today/presentation/today_screen.dart';

/// One day's timeline, opened from the week or month view (section 8).
class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key, required this.initialDate});

  final LocalDate initialDate;

  static Future<void> open(BuildContext context, LocalDate date) =>
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DayScreen(initialDate: date)));

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  late LocalDate _date = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final location = ref.watch(locationProvider);
    final ethiopian = ref.watch(userProvider).value?.calendarType == 'ethiopian';
    final occurrences = ref.watch(dayOccurrencesProvider(_date));

    return Scaffold(
      appBar: AppBar(
        title: Text(formatLongDate(context, _date, ethiopian: ethiopian)),
        actions: [
          IconButton(
            tooltip: l.previous,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _date = _date.addDays(-1)),
          ),
          IconButton(
            tooltip: l.next,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _date = _date.addDays(1)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l.newTask,
        onPressed: () => TaskEditorScreen.open(context, initialDate: _date),
        child: const Icon(Icons.add),
      ),
      body: switch (occurrences) {
        AsyncData(:final value) when value.isEmpty =>
          EmptyDay(icon: Icons.event_available_outlined, title: l.noTasks),
        AsyncData(:final value) => DayTimeline(
            key: ValueKey(_date),
            items: value,
            day: _date,
            location: location,
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
