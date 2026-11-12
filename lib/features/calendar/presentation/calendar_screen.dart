import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/providers.dart';
import '../../../core/utils/calendar_month.dart';
import '../../../core/utils/date_display.dart';
import '../../../core/utils/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/scheduling.dart';
import '../../tasks/presentation/occurrence_actions.dart';
import '../../tasks/presentation/occurrence_sheet.dart';
import 'day_screen.dart';

enum _View { week, month }

/// Calendar tab: week and month views; tap a day to open its timeline
/// (FR-12). The month grid follows the chosen calendar, so in Ethiopian mode
/// it shows Ethiopian months, including the 5/6-day Pagume (FR-20).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _View _view = _View.month;
  LocalDate? _anchor; // a date inside the period shown; null = today

  LocalDate _today(tz.Location location) =>
      LocalDate.fromDateTime(tz.TZDateTime.now(location));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final location = ref.watch(locationProvider);
    final ethiopian = ref.watch(userProvider).value?.calendarType == 'ethiopian';
    final today = _today(location);
    final anchor = _anchor ?? today;

    late final LocalDate from;
    late final LocalDate to;
    late final String title;
    late final LocalDate Function(int step) shift;
    CalendarMonth? month;

    if (_view == _View.week) {
      from = anchor.startOfWeek;
      to = from.addDays(6);
      title = '${formatShortDate(context, from, ethiopian: ethiopian)} – '
          '${formatShortDate(context, to, ethiopian: ethiopian)}';
      shift = (step) => anchor.addDays(7 * step);
    } else {
      month = CalendarMonth.containing(anchor, ethiopian: ethiopian);
      from = month.first;
      to = month.last;
      title = formatMonthTitle(context, month);
      shift = (step) => (step < 0 ? month!.previous : month!.next).first;
    }

    final occurrences = ref.watch(rangeOccurrencesProvider((from: from, to: to)));
    final byDay = <LocalDate, List<OccurrenceView>>{};
    for (final o in occurrences.value ?? const <OccurrenceView>[]) {
      final day = LocalDate.fromDateTime(
          tz.TZDateTime.from(o.occurrence.scheduledStart, location));
      byDay.putIfAbsent(day, () => []).add(o);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.tabCalendar),
        actions: [
          TextButton(
            onPressed: () => setState(() => _anchor = null),
            child: Text(l.goToToday),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_View>(
              segments: [
                ButtonSegment(value: _View.week, label: Text(l.viewWeek)),
                ButtonSegment(value: _View.month, label: Text(l.viewMonth)),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: l.previous,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _anchor = shift(-1)),
              ),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                tooltip: l.next,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _anchor = shift(1)),
              ),
            ],
          ),
          Expanded(
            child: occurrences.hasError
                ? Center(child: Text('${occurrences.error}'))
                : _view == _View.week
                    ? _WeekView(
                        from: from,
                        today: today,
                        byDay: byDay,
                        ethiopian: ethiopian,
                        location: location,
                      )
                    : _MonthView(month: month!, today: today, byDay: byDay),
          ),
        ],
      ),
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.from,
    required this.today,
    required this.byDay,
    required this.ethiopian,
    required this.location,
  });

  final LocalDate from;
  final LocalDate today;
  final Map<LocalDate, List<OccurrenceView>> byDay;
  final bool ethiopian;
  final tz.Location location;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: 7,
      itemBuilder: (context, i) {
        final day = from.addDays(i);
        final items = byDay[day] ?? const [];
        final isToday = day == today;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              dense: true,
              title: Text(
                formatLongDate(context, day, ethiopian: ethiopian),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isToday ? theme.colorScheme.primary : null,
                  fontWeight: isToday ? FontWeight.bold : null,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => DayScreen.open(context, day),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(l.noTasks,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
            for (final item in items)
              ListTile(
                dense: true,
                leading: Icon(
                  switch (item.status) {
                    OccurrenceStatus.done => Icons.check_circle,
                    OccurrenceStatus.skipped => Icons.redo,
                    OccurrenceStatus.missed => Icons.error_outline,
                    OccurrenceStatus.pending => Icons.circle_outlined,
                  },
                  color: item.category == null
                      ? theme.colorScheme.primary
                      : Color(item.category!.color),
                ),
                title: Text(item.task.title),
                subtitle: Text([
                  formatTime(context,
                      tz.TZDateTime.from(item.occurrence.scheduledStart, location)),
                  if (!item.isProjected) statusLabel(l, item.status),
                ].join(' · ')),
                onTap: () => OccurrenceSheet.show(context, item),
              ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({required this.month, required this.today, required this.byDay});

  final CalendarMonth month;
  final LocalDate today;
  final Map<LocalDate, List<OccurrenceView>> byDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cells = month.gridCells();
    final weekdays = weekdayInitials(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Row(children: [
              for (final w in weekdays)
                Expanded(
                  child: Center(
                    child: Text(w,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.labelSmall),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.8,
              ),
              itemCount: cells.length,
              itemBuilder: (context, i) {
                final day = cells[i];
                if (day == null) return const SizedBox.shrink();
                return _DayCell(
                  dayNumber: month.dayOf(day),
                  isToday: day == today,
                  items: byDay[day] ?? const [],
                  onTap: () => DayScreen.open(context, day),
                  semanticDate: formatLongDate(context, day,
                      ethiopian: month.ethiopian),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNumber,
    required this.isToday,
    required this.items,
    required this.onTap,
    required this.semanticDate,
  });

  final int dayNumber;
  final bool isToday;
  final List<OccurrenceView> items;
  final VoidCallback onTap;
  final String semanticDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final shown = items.take(4).toList();

    return Semantics(
      button: true,
      label: '$semanticDate, ${items.isEmpty ? l.noTasks : '${items.length}'}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
                      : null,
                  child: Text(
                    '$dayNumber',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isToday ? scheme.onPrimary : null,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final item in shown)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (item.category == null
                                  ? scheme.primary
                                  : Color(item.category!.color))
                              .withValues(
                                  alpha: item.status == OccurrenceStatus.pending
                                      ? 1
                                      : 0.35),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
