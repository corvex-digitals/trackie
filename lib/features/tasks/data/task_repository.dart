import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/database/app_database.dart';
import '../../../core/notifications/reminder_scheduler.dart';
import '../../../core/utils/local_date.dart';
import '../domain/recurrence.dart';
import '../domain/scheduling.dart';
import '../domain/task_draft.dart';

/// An occurrence with the task (and category) it belongs to, for display.
class OccurrenceView {
  OccurrenceView(this.occurrence, this.task,
      {this.category, this.isProjected = false});
  final Occurrence occurrence;
  final Task task;
  final Category? category;

  /// Beyond the 14-day window: computed from the series for the calendar,
  /// not stored. It can be viewed and its series edited, but not tracked.
  final bool isProjected;

  OccurrenceStatus get status =>
      OccurrenceStatus.values.byName(occurrence.status);
}

/// Tasks, their occurrences, and tracking. The local database is the source
/// of truth; every mutation ends with a [ReminderScheduler.resync] so OS
/// alarms always match the data.
class TaskRepository {
  TaskRepository(this._db, this._scheduler, {DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;

  // ---------------------------------------------------------------- profile

  /// Returns the local user id, creating the profile on first launch (FR-01).
  Future<String> ensureLocalUser(String timezone) async {
    final existing = await (_db.select(_db.users)..limit(1)).getSingleOrNull();
    if (existing != null) return existing.id;
    final user = await _db
        .into(_db.users)
        .insertReturning(UsersCompanion.insert(timezone: timezone));
    return user.id;
  }

  // ------------------------------------------------------------------ series

  /// Creates a task, materialises its occurrences for the rolling window and
  /// registers its alerts (FR-03, FR-04, FR-07).
  Future<String> createTask(TaskDraft draft) async {
    final now = _clock();
    final taskId = await _db.transaction(() async {
      final userId = await ensureLocalUser(draft.timezone);
      final task = await _db.into(_db.tasks).insertReturning(
            TasksCompanion.insert(
              userId: userId,
              title: draft.title.trim(),
              notes: Value(draft.notes),
              categoryId: Value(draft.categoryId),
              startDate: draft.startDate.toIso(),
              startMinute: Value(draft.startMinute),
              durationMin: Value(draft.durationMin),
              priority: Value(draft.priority.name),
              isAllDay: Value(draft.isAllDay),
              timezone: draft.timezone,
            ),
          );
      await _writeRule(task.id, draft.rule);
      await _writeReminders(task.id, draft.reminderOffsets);
      await _materialise(task.id, now);
      return task.id;
    });
    await _scheduler.resync(now);
    return taskId;
  }

  /// Updates the whole series (FR-05). Past occurrences and those edited on
  /// their own are kept; future pending ones are re-planned.
  Future<void> updateSeries(String taskId, TaskDraft draft) async {
    final now = _clock();
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          title: Value(draft.title.trim()),
          notes: Value(draft.notes),
          categoryId: Value(draft.categoryId),
          startDate: Value(draft.startDate.toIso()),
          startMinute: Value(draft.startMinute),
          durationMin: Value(draft.durationMin),
          priority: Value(draft.priority.name),
          isAllDay: Value(draft.isAllDay),
          timezone: Value(draft.timezone),
          updatedAt: Value(now),
        ),
      );
      await _writeRule(taskId, draft.rule);
      await _writeReminders(taskId, draft.reminderOffsets);
      await _materialise(taskId, now);
    });
    await _scheduler.resync(now);
  }

  /// Deletes the series (FR-05). Completed history stays for statistics;
  /// upcoming pending occurrences are removed.
  Future<void> deleteSeries(String taskId) async {
    final now = _clock();
    await _db.transaction(() async {
      final deleted = Value<DateTime?>(now);
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId)))
          .write(TasksCompanion(deletedAt: deleted, updatedAt: Value(now)));
      await (_db.update(_db.recurrenceRules)
            ..where((r) => r.taskId.equals(taskId)))
          .write(RecurrenceRulesCompanion(deletedAt: deleted, updatedAt: Value(now)));
      await (_db.update(_db.reminders)..where((r) => r.taskId.equals(taskId)))
          .write(RemindersCompanion(deletedAt: deleted, updatedAt: Value(now)));
      await (_db.update(_db.occurrences)
            ..where((o) =>
                o.taskId.equals(taskId) &
                o.status.equals(OccurrenceStatus.pending.name) &
                o.scheduledEnd.isBiggerOrEqualValue(now)))
          .write(OccurrencesCompanion(deletedAt: deleted, updatedAt: Value(now)));
    });
    await _scheduler.resync(now);
  }

  // -------------------------------------------------------- single occurrence

  /// Deletes one occurrence of a series (FR-05). It is soft-deleted and marked
  /// as an exception so the window extension never recreates it.
  Future<void> deleteOccurrence(String occurrenceId) async {
    final now = _clock();
    await (_db.update(_db.occurrences)..where((o) => o.id.equals(occurrenceId)))
        .write(OccurrencesCompanion(
      deletedAt: Value(now),
      isException: const Value(true),
      updatedAt: Value(now),
    ));
    await _scheduler.resync(now);
  }

  /// Moves one occurrence (FR-05, and the basis of FR-15 rescheduling).
  Future<void> rescheduleOccurrence(
    String occurrenceId, {
    required DateTime newStartUtc,
    int? durationMin,
  }) async {
    final now = _clock();
    await _db.transaction(() async {
      final occ = await (_db.select(_db.occurrences)
            ..where((o) => o.id.equals(occurrenceId)))
          .getSingle();
      final duration = durationMin != null
          ? Duration(minutes: durationMin)
          : occ.scheduledEnd.difference(occ.scheduledStart);
      await (_db.update(_db.occurrences)
            ..where((o) => o.id.equals(occurrenceId)))
          .write(OccurrencesCompanion(
        scheduledStart: Value(newStartUtc),
        scheduledEnd: Value(newStartUtc.add(duration)),
        status: Value(OccurrenceStatus.pending.name),
        completedAt: const Value(null),
        isException: const Value(true),
        updatedAt: Value(now),
      ));
      await _log(occurrenceId, 'rescheduled', now);
    });
    await _scheduler.resync(now);
  }

  /// Marks an occurrence done / skipped, or back to pending (FR-14).
  Future<void> setStatus(String occurrenceId, OccurrenceStatus status) async {
    final now = _clock();
    await _db.transaction(() async {
      await (_db.update(_db.occurrences)
            ..where((o) => o.id.equals(occurrenceId)))
          .write(OccurrencesCompanion(
        status: Value(status.name),
        completedAt: Value(status == OccurrenceStatus.done ? now : null),
        updatedAt: Value(now),
      ));
      await _log(occurrenceId, status.name, now);
    });
    await _scheduler.resync(now);
  }

  /// Re-alerts in [delay] (FR-09, from the app; the notification has its own
  /// buttons).
  Future<void> snooze(String occurrenceId, Duration delay) =>
      _scheduler.snooze(occurrenceId, delay, _clock());

  // ------------------------------------------------------------ maintenance

  /// Maintenance (section 7), run on start, on resume and by the background
  /// job: follow a device time-zone change, mark overdue occurrences as
  /// missed, extend every active series to today + 14 days, re-register
  /// alarms.
  Future<void> runMaintenance({String? deviceZone}) async {
    final now = _clock();
    await _db.transaction(() async {
      if (deviceZone != null) await _followTimezone(deviceZone, now);
      await _markMissed(now);
      final active = await (_db.select(_db.tasks)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      for (final task in active) {
        await _materialise(task.id, now);
      }
    });
    await _scheduler.resync(now);
  }

  /// Tasks are wall-clock plans ("gym at 18:00"), so after travelling or a
  /// time-zone change they follow the device's new local time. Past and
  /// individually edited occurrences keep their instants.
  Future<void> _followTimezone(String zone, DateTime now) async {
    tz.getLocation(zone); // throws on an unknown zone before anything changes
    await (_db.update(_db.users)..where((u) => u.timezone.equals(zone).not()))
        .write(UsersCompanion(timezone: Value(zone), updatedAt: Value(now)));
    await (_db.update(_db.tasks)
          ..where((t) => t.deletedAt.isNull() & t.timezone.equals(zone).not()))
        .write(TasksCompanion(timezone: Value(zone), updatedAt: Value(now)));
  }

  /// Permanently erases everything stored on the device and cancels every
  /// alert (NFR-08). The caller recreates the local profile.
  Future<void> deleteAllData() async {
    await _scheduler.cancelAll();
    await _db.transaction(() async {
      // Children before parents, for the foreign keys.
      for (final table in <TableInfo>[
        _db.activityLogs,
        _db.scheduledNotifications,
        _db.occurrences,
        _db.reminders,
        _db.recurrenceRules,
        _db.routineItems,
        _db.routines,
        _db.tasks,
        _db.categories,
        _db.users,
        _db.syncState,
      ]) {
        await _db.delete(table).go();
      }
    });
  }

  Future<void> _markMissed(DateTime now) async {
    final candidates = await (_db.select(_db.occurrences)
          ..where((o) =>
              o.status.equals(OccurrenceStatus.pending.name) &
              o.deletedAt.isNull() &
              o.scheduledEnd.isSmallerThanValue(now)))
        .get();
    for (final occ in candidates) {
      if (!isOverdue(
          status: OccurrenceStatus.pending,
          scheduledEndUtc: occ.scheduledEnd,
          nowUtc: now)) {
        continue;
      }
      await (_db.update(_db.occurrences)..where((o) => o.id.equals(occ.id)))
          .write(OccurrencesCompanion(
        status: Value(OccurrenceStatus.missed.name),
        updatedAt: Value(now),
      ));
      await _log(occ.id, 'missed', now);
    }
  }

  // ------------------------------------------------------------------ queries

  /// Occurrences overlapping [date] in [location], in start order (FR-12).
  Stream<List<OccurrenceView>> watchDay(LocalDate date, tz.Location location) =>
      watchRange(date, date, location);

  /// Occurrences overlapping the local days [from]..[to] (inclusive), in
  /// start order, for the timeline and the week/month views (FR-12).
  ///
  /// Stored occurrences cover history and the 14-day window. Later dates are
  /// projected from each series on the fly ([OccurrenceView.isProjected]),
  /// so the calendar can show any future month without storing it.
  Stream<List<OccurrenceView>> watchRange(
      LocalDate from, LocalDate to, tz.Location location) {
    final rangeStart = wallClockToUtc(from, 0, location);
    final rangeEnd = wallClockToUtc(to.addDays(1), 0, location);
    final o = _db.occurrences;
    final query = _db.select(o).join([
      innerJoin(_db.tasks, _db.tasks.id.equalsExp(o.taskId)),
      leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.tasks.categoryId) &
              _db.categories.deletedAt.isNull()),
    ])
      ..where(o.deletedAt.isNull() &
          _db.tasks.deletedAt.isNull() &
          o.scheduledStart.isSmallerThanValue(rangeEnd) &
          (o.scheduledEnd.isBiggerThanValue(rangeStart) |
              o.scheduledStart.isBiggerOrEqualValue(rangeStart)))
      ..orderBy([OrderingTerm.asc(o.scheduledStart)]);

    return query.watch().asyncMap((rows) async {
      final stored = [
        for (final r in rows)
          OccurrenceView(r.readTable(o), r.readTable(_db.tasks),
              category: r.readTableOrNull(_db.categories)),
      ];
      final projected = await _project(from, to, rangeStart, rangeEnd);
      if (projected.isEmpty) return stored;
      return [...stored, ...projected]
        ..sort((a, b) =>
            a.occurrence.scheduledStart.compareTo(b.occurrence.scheduledStart));
    });
  }

  /// Series dates in [from]..[to] from today on that have no stored row
  /// (normally those beyond the window; deleted occurrences keep their row,
  /// so they are not resurrected here).
  Future<List<OccurrenceView>> _project(LocalDate from, LocalDate to,
      DateTime rangeStart, DateTime rangeEnd) async {
    final now = _clock();
    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    if (tasks.isEmpty) return const [];

    final rules = {
      for (final r in await (_db.select(_db.recurrenceRules)
            ..where((r) => r.deletedAt.isNull()))
          .get())
        r.taskId: _ruleFromRow(r),
    };
    final categories = {
      for (final c in await (_db.select(_db.categories)
            ..where((c) => c.deletedAt.isNull()))
          .get())
        c.id: c,
    };
    // Keys of every stored row near the range, including deleted ones. One
    // day of margin covers tasks whose time zone differs from the display's.
    final existing = {
      for (final row in await (_db.select(_db.occurrences)
            ..where((x) => x.occurrenceDate.isBetweenValues(
                from.addDays(-1).toIso(), to.addDays(1).toIso())))
          .get())
        '${row.taskId}|${row.occurrenceDate}',
    };

    final result = <OccurrenceView>[];
    for (final task in tasks) {
      final location = tz.getLocation(task.timezone);
      final today = localDateOf(now, location);
      final first = from.addDays(-1).isBefore(today) ? today : from.addDays(-1);
      final last = to.addDays(1);
      if (last.isBefore(first)) continue;

      for (final date in occurrenceDates(
        start: LocalDate.parse(task.startDate),
        rule: rules[task.id],
        from: first,
        to: last,
      )) {
        if (existing.contains('${task.id}|${date.toIso()}')) continue;
        final (start, end) = _instantsFor(task, date, location);
        final overlaps = start.isBefore(rangeEnd) &&
            (end.isAfter(rangeStart) || !start.isBefore(rangeStart));
        if (!overlaps) continue;
        result.add(OccurrenceView(
          Occurrence(
            id: 'projected:${task.id}:${date.toIso()}',
            createdAt: now,
            updatedAt: now,
            taskId: task.id,
            occurrenceDate: date.toIso(),
            scheduledStart: start,
            scheduledEnd: end,
            status: OccurrenceStatus.pending.name,
            isException: false,
          ),
          task,
          category: categories[task.categoryId],
          isProjected: true,
        ));
      }
    }
    return result;
  }

  /// One stored occurrence with its task, e.g. for a tapped notification.
  Future<OccurrenceView?> occurrenceById(String id) async {
    final o = _db.occurrences;
    final row = await (_db.select(o).join([
      innerJoin(_db.tasks, _db.tasks.id.equalsExp(o.taskId)),
      leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.tasks.categoryId) &
              _db.categories.deletedAt.isNull()),
    ])
          ..where(o.id.equals(id) &
              o.deletedAt.isNull() &
              _db.tasks.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) return null;
    return OccurrenceView(row.readTable(o), row.readTable(_db.tasks),
        category: row.readTableOrNull(_db.categories));
  }

  Future<RecurrenceRule?> ruleFor(String taskId) async {
    final row = await (_db.select(_db.recurrenceRules)
          ..where((r) => r.taskId.equals(taskId) & r.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _ruleFromRow(row);
  }

  Future<List<int>> reminderOffsetsFor(String taskId) async {
    final rows = await (_db.select(_db.reminders)
          ..where((r) => r.taskId.equals(taskId) & r.deletedAt.isNull()))
        .get();
    return rows.map((r) => r.offsetMin).toList()..sort();
  }

  // ---------------------------------------------------------------- internal

  /// Reconciles a task's stored occurrences with its plan for the window
  /// [today .. today + windowDays] in the task's own time zone.
  ///
  /// * missing dates are inserted;
  /// * pending, non-exception rows get their times refreshed (and are revived
  ///   if they had been dropped by an earlier series edit);
  /// * pending, non-exception rows whose date left the plan are soft-deleted;
  /// * done/skipped/missed rows and single-occurrence exceptions are untouched.
  Future<void> _materialise(String taskId, DateTime nowUtc) async {
    final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId)))
        .getSingle();
    final location = tz.getLocation(task.timezone);
    final from = localDateOf(nowUtc, location);
    final to = from.addDays(SchedulingPolicy.windowDays);
    final rule = await ruleFor(taskId);

    final dates = occurrenceDates(
      start: LocalDate.parse(task.startDate),
      rule: rule,
      from: from,
      to: to,
    ).toSet();

    final existing = await (_db.select(_db.occurrences)
          ..where((o) =>
              o.taskId.equals(taskId) &
              o.occurrenceDate.isBetweenValues(from.toIso(), to.toIso())))
        .get();
    final byDate = {for (final e in existing) e.occurrenceDate: e};

    for (final date in dates) {
      final (start, end) = _instantsFor(task, date, location);
      final row = byDate[date.toIso()];

      if (row == null) {
        await _db.into(_db.occurrences).insert(OccurrencesCompanion.insert(
              taskId: taskId,
              occurrenceDate: date.toIso(),
              scheduledStart: start,
              scheduledEnd: end,
            ));
      } else if (_isReplannable(row) &&
          (!row.scheduledStart.isAtSameMomentAs(start) ||
              !row.scheduledEnd.isAtSameMomentAs(end) ||
              row.deletedAt != null)) {
        await (_db.update(_db.occurrences)..where((o) => o.id.equals(row.id)))
            .write(OccurrencesCompanion(
          scheduledStart: Value(start),
          scheduledEnd: Value(end),
          deletedAt: const Value(null),
          updatedAt: Value(nowUtc),
        ));
      }
    }

    for (final row in existing) {
      if (_isReplannable(row) &&
          row.deletedAt == null &&
          !dates.contains(LocalDate.parse(row.occurrenceDate))) {
        await (_db.update(_db.occurrences)..where((o) => o.id.equals(row.id)))
            .write(OccurrencesCompanion(
          deletedAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
        ));
      }
    }
  }

  /// UTC start and end of [task] on the local [date].
  static (DateTime, DateTime) _instantsFor(
      Task task, LocalDate date, tz.Location location) {
    if (task.isAllDay) {
      return (
        wallClockToUtc(date, 0, location),
        wallClockToUtc(date.addDays(1), 0, location),
      );
    }
    final start = wallClockToUtc(date, task.startMinute, location);
    return (start, start.add(Duration(minutes: task.durationMin)));
  }

  bool _isReplannable(Occurrence o) =>
      !o.isException && o.status == OccurrenceStatus.pending.name;

  Future<void> _writeRule(String taskId, RecurrenceRule? rule) async {
    final now = _clock();
    final existing = await (_db.select(_db.recurrenceRules)
          ..where((r) => r.taskId.equals(taskId)))
        .getSingleOrNull();
    if (rule == null) {
      if (existing != null && existing.deletedAt == null) {
        await (_db.update(_db.recurrenceRules)
              ..where((r) => r.id.equals(existing.id)))
            .write(RecurrenceRulesCompanion(
                deletedAt: Value(now), updatedAt: Value(now)));
      }
      return;
    }
    final values = RecurrenceRulesCompanion(
      taskId: Value(taskId),
      frequency: Value(rule.frequency.name),
      interval: Value(rule.interval),
      byWeekdays: Value(rule.byWeekdays.isEmpty ? null : rule.byWeekdaysCsv),
      endDate: Value(rule.endDate?.toIso()),
      count: Value(rule.count),
      deletedAt: const Value(null),
      updatedAt: Value(now),
    );
    if (existing == null) {
      await _db.into(_db.recurrenceRules).insert(values);
    } else {
      await (_db.update(_db.recurrenceRules)
            ..where((r) => r.id.equals(existing.id)))
          .write(values);
    }
  }

  Future<void> _writeReminders(String taskId, List<int> offsets) async {
    final now = _clock();
    final wanted = offsets.toSet();
    final existing = await (_db.select(_db.reminders)
          ..where((r) => r.taskId.equals(taskId) & r.deletedAt.isNull()))
        .get();
    for (final r in existing) {
      if (!wanted.remove(r.offsetMin)) {
        await (_db.update(_db.reminders)..where((x) => x.id.equals(r.id)))
            .write(RemindersCompanion(
                deletedAt: Value(now), updatedAt: Value(now)));
      }
    }
    for (final offset in wanted) {
      await _db.into(_db.reminders).insert(RemindersCompanion.insert(
            taskId: taskId,
            offsetMin: Value(offset),
          ));
    }
  }

  Future<void> _log(String occurrenceId, String action, DateTime at) =>
      _db.into(_db.activityLogs).insert(ActivityLogsCompanion.insert(
            occurrenceId: occurrenceId,
            action: action,
            at: at,
          ));

  static RecurrenceRule _ruleFromRow(RecurrenceRuleRow row) => RecurrenceRule(
        frequency: Frequency.values.byName(row.frequency),
        interval: row.interval,
        byWeekdays: RecurrenceRule.parseWeekdays(row.byWeekdays),
        endDate: row.endDate == null ? null : LocalDate.parse(row.endDate!),
        count: row.count,
      );
}
