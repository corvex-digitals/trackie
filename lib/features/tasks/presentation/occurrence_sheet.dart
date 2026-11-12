import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/providers.dart';
import '../../../core/utils/date_display.dart';
import '../../../core/utils/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category_style.dart';
import '../data/task_repository.dart';
import '../domain/scheduling.dart';
import 'occurrence_actions.dart';
import 'task_editor_screen.dart';

/// Actions for one occurrence (section 8): done / skip / snooze /
/// reschedule / edit. Opened by tapping a task or its notification.
class OccurrenceSheet extends ConsumerWidget {
  const OccurrenceSheet({super.key, required this.item});

  final OccurrenceView item;

  static Future<void> show(BuildContext context, OccurrenceView item) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => OccurrenceSheet(item: item),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final location = ref.watch(locationProvider);
    final ethiopian = ref.watch(userProvider).value?.calendarType == 'ethiopian';
    final start = tz.TZDateTime.from(item.occurrence.scheduledStart, location);
    final end = tz.TZDateTime.from(item.occurrence.scheduledEnd, location);
    final status = item.status;
    final category = item.category;
    final repo = ref.read(taskRepositoryProvider);

    void close() => Navigator.of(context).pop();

    Future<void> mark(OccurrenceStatus s) async {
      // Starts (and captures context-dependent objects) before the sheet closes.
      final done = markOccurrence(context, ref, item, s);
      close();
      await done;
    }

    Future<void> snooze(Duration d) async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      close();
      await repo.snooze(item.occurrence.id, d);
      messenger?.showSnackBar(
          SnackBar(content: Text(l.snoozedFor(d.inMinutes))));
    }

    Future<void> reschedule() async {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime(start.year, start.month, start.day),
        firstDate: DateTime(start.year - 1),
        lastDate: DateTime(start.year + 5),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: start.hour, minute: start.minute),
      );
      if (time == null || !context.mounted) return;
      final newStart = wallClockToUtc(
          LocalDate.fromDateTime(date), time.hour * 60 + time.minute, location);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final label = formatMinuteOfDay(context, time.hour * 60 + time.minute);
      close();
      await repo.rescheduleOccurrence(item.occurrence.id, newStartUtc: newStart);
      messenger?.showSnackBar(SnackBar(content: Text(l.rescheduled(label))));
    }

    void edit() {
      final navigator = Navigator.of(context);
      navigator.pop();
      TaskEditorScreen.open(navigator.context, existing: item);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.task.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${formatLongDate(context, LocalDate.fromDateTime(start), ethiopian: ethiopian)}\n'
              '${l.timeRange(formatTime(context, start), formatTime(context, end))}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              if (category != null)
                Chip(
                  avatar: Icon(CategoryStyle.icon(category.icon),
                      size: 18, color: Color(category.color)),
                  label: Text(category.name),
                ),
              if (!item.isProjected) Chip(label: Text(statusLabel(l, status))),
            ]),
            if (item.task.notes != null) ...[
              const SizedBox(height: 8),
              Text(item.task.notes!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 16),
            if (item.isProjected) ...[
              Text(l.projectedNote, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: edit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.editSeries),
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status != OccurrenceStatus.done)
                    FilledButton.icon(
                      onPressed: () => mark(OccurrenceStatus.done),
                      icon: const Icon(Icons.check),
                      label: Text(l.actionDone),
                    ),
                  if (status == OccurrenceStatus.pending ||
                      status == OccurrenceStatus.missed)
                    OutlinedButton.icon(
                      onPressed: () => mark(OccurrenceStatus.skipped),
                      icon: const Icon(Icons.redo),
                      label: Text(l.actionSkip),
                    ),
                  if (status != OccurrenceStatus.pending)
                    OutlinedButton.icon(
                      onPressed: () => mark(OccurrenceStatus.pending),
                      icon: const Icon(Icons.undo),
                      label: Text(l.actionReset),
                    ),
                ],
              ),
              if (status == OccurrenceStatus.pending) ...[
                const SizedBox(height: 16),
                Text(l.actionSnooze, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final d in SchedulingPolicy.snoozeOptions)
                    ActionChip(
                      avatar: const Icon(Icons.snooze, size: 18),
                      label: Text(l.snoozeMinutes(d.inMinutes)),
                      onPressed: () => snooze(d),
                    ),
                ]),
              ],
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(l.actionReschedule),
                onTap: reschedule,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.actionEdit),
                onTap: edit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
