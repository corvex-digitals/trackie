import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/providers.dart';
import '../../../core/utils/date_display.dart';
import '../../../core/utils/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/scheduling.dart';
import '../../tasks/presentation/occurrence_sheet.dart';
import 'day_timeline.dart';

/// Today tab (FR-12): next-task card and the day's hour-by-hour timeline.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Refreshes the next-up card and rolls over to the next day at midnight.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final location = ref.watch(locationProvider);
    final now = tz.TZDateTime.now(location);
    final today = LocalDate.fromDateTime(now);
    final ethiopian = ref.watch(userProvider).value?.calendarType == 'ethiopian';
    final occurrences = ref.watch(dayOccurrencesProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabToday),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(formatLongDate(context, today, ethiopian: ethiopian)),
          ),
        ),
      ),
      body: switch (occurrences) {
        AsyncData(:final value) when value.isEmpty => EmptyDay(
            icon: Icons.wb_sunny_outlined,
            title: l.emptyTodayTitle,
            body: l.emptyTodayBody,
          ),
        AsyncData(:final value) => Column(
            children: [
              _NextUpCard(items: value, now: now, location: location),
              Expanded(
                child: DayTimeline(
                  key: ValueKey(today),
                  items: value,
                  day: today,
                  location: location,
                ),
              ),
            ],
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Placeholder for a day with nothing planned.
class EmptyDay extends StatelessWidget {
  const EmptyDay({super.key, required this.icon, required this.title, this.body});
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(body!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard(
      {required this.items, required this.now, required this.location});
  final List<OccurrenceView> items;
  final DateTime now;
  final tz.Location location;

  @override
  Widget build(BuildContext context) {
    final next = items
        .where((i) =>
            i.status == OccurrenceStatus.pending &&
            i.occurrence.scheduledEnd.isAfter(now))
        .firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final start = tz.TZDateTime.from(next.occurrence.scheduledStart, location);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(next.task.title),
        subtitle: Text(
            '${AppLocalizations.of(context).nextUp} · ${formatTime(context, start)}'),
        onTap: () => OccurrenceSheet.show(context, next),
      ),
    );
  }
}
