import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:trackie/core/database/app_database.dart';
import 'package:trackie/core/notifications/reminder_scheduler.dart';
import 'package:trackie/core/utils/local_date.dart';
import 'package:trackie/features/categories/data/category_repository.dart';
import 'package:trackie/features/tasks/data/task_repository.dart';
import 'package:trackie/features/tasks/domain/recurrence.dart';
import 'package:trackie/features/tasks/domain/scheduling.dart';
import 'package:trackie/features/tasks/domain/task_draft.dart';

import '../../../support/fake_notification_gateway.dart';

const zone = 'Africa/Addis_Ababa'; // UTC+3, no DST

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late FakeNotificationGateway gateway;
  late ReminderScheduler scheduler;
  late TaskRepository repo;
  // 2026-11-03 08:00 in Addis Ababa.
  var now = DateTime.utc(2026, 11, 3, 5);

  setUp(() {
    now = DateTime.utc(2026, 11, 3, 5);
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    gateway = FakeNotificationGateway();
    scheduler = ReminderScheduler(db, gateway);
    repo = TaskRepository(db, scheduler, clock: () => now);
  });

  tearDown(() => db.close());

  TaskDraft draft({
    String title = 'Gym',
    int startMinute = 18 * 60,
    RecurrenceRule? rule,
    List<int> reminders = const [10],
    LocalDate? start,
  }) =>
      TaskDraft(
        title: title,
        startDate: start ?? LocalDate(2026, 11, 3),
        startMinute: startMinute,
        durationMin: 60,
        timezone: zone,
        rule: rule,
        reminderOffsets: reminders,
      );

  Future<List<Occurrence>> liveOccurrences() => (db.select(db.occurrences)
        ..where((o) => o.deletedAt.isNull())
        ..orderBy([(o) => OrderingTerm.asc(o.scheduledStart)]))
      .get();

  Iterable<ScheduledAlert> futureAlerts() =>
      gateway.active.values.where((a) => a.fireAtUtc.isAfter(now));

  test('one-off task: one occurrence, one alarm at the right instant', () async {
    await repo.createTask(draft());
    final occ = await liveOccurrences();
    expect(occ, hasLength(1));
    expect(occ.single.scheduledStart, DateTime.utc(2026, 11, 3, 15));
    expect(occ.single.scheduledEnd, DateTime.utc(2026, 11, 3, 16));
    expect(gateway.active.values.single.fireAtUtc, DateTime.utc(2026, 11, 3, 14, 50));
    expect(gateway.active.values.single.title, 'Gym');
    expect(gateway.active.values.single.body, contains('18:00'));
  });

  test('daily task materialises today + 14 days and an alarm per reminder', () async {
    await repo.createTask(draft(
      rule: RecurrenceRule(frequency: Frequency.daily),
      reminders: [0, 10],
    ));
    expect(await liveOccurrences(), hasLength(SchedulingPolicy.windowDays + 1));
    expect(gateway.active, hasLength(2 * (SchedulingPolicy.windowDays + 1)));
  });

  test('no alarms for times already past', () async {
    await repo.createTask(draft(startMinute: 7 * 60)); // 07:00, now is 08:00
    expect(await liveOccurrences(), hasLength(1));
    expect(gateway.active, isEmpty);
  });

  test('maintenance is idempotent', () async {
    await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    final calls = gateway.scheduleCalls;
    final before = {for (final o in await liveOccurrences()) o.id: o.updatedAt};
    now = now.add(const Duration(minutes: 5));
    await repo.runMaintenance();
    await repo.runMaintenance();
    final occ = await liveOccurrences();
    expect(occ, hasLength(15));
    // Unchanged rows must not be touched, or sync would re-upload them all.
    expect({for (final o in occ) o.id: o.updatedAt}, before);
    expect(gateway.scheduleCalls, calls);
    expect(gateway.cancelCalls, 0);
  });

  test('window rolls forward with the clock', () async {
    await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    now = now.add(const Duration(days: 1));
    await repo.runMaintenance();
    final occ = await liveOccurrences();
    expect(occ.last.occurrenceDate, '2026-11-18');
    expect(occ.where((o) => o.status == 'pending'), hasLength(15)); // 11-04..11-18
    expect(occ.first.status, 'missed'); // yesterday's was never answered
  });

  test('missed only after end + grace period', () async {
    await repo.createTask(draft(startMinute: 9 * 60)); // 09:00–10:00 local
    now = DateTime.utc(2026, 11, 3, 7, 30); // 10:30 local: inside grace
    await repo.runMaintenance();
    expect((await liveOccurrences()).single.status, 'pending');
    now = DateTime.utc(2026, 11, 3, 7, 31);
    await repo.runMaintenance();
    expect((await liveOccurrences()).single.status, 'missed');
  });

  test('marking done cancels its alarms and logs the action', () async {
    await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    final first = (await liveOccurrences()).first;
    expect(gateway.forOccurrence(first.id), hasLength(1));

    await repo.setStatus(first.id, OccurrenceStatus.done);
    expect(gateway.forOccurrence(first.id), isEmpty);
    final updated = (await liveOccurrences()).first;
    expect(updated.status, 'done');
    expect(updated.completedAt, now);
    final logs = await db.select(db.activityLogs).get();
    expect(logs.single.action, 'done');

    // Undo restores the alarm.
    await repo.setStatus(first.id, OccurrenceStatus.pending);
    expect(gateway.forOccurrence(first.id), hasLength(1));
  });

  test('deleting one occurrence survives window extension', () async {
    await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    final second = (await liveOccurrences())[1];
    await repo.deleteOccurrence(second.id);
    await repo.runMaintenance();
    final occ = await liveOccurrences();
    expect(occ, hasLength(14));
    expect(occ.map((o) => o.occurrenceDate), isNot(contains(second.occurrenceDate)));
    expect(gateway.forOccurrence(second.id), isEmpty);
  });

  test('series edit moves future pending occurrences, keeps history and exceptions', () async {
    final taskId = await repo.createTask(
        draft(startMinute: 6 * 60, rule: RecurrenceRule(frequency: Frequency.daily)));
    var occ = await liveOccurrences();
    await repo.setStatus(occ[0].id, OccurrenceStatus.done); // today, done
    final moved = DateTime.utc(2026, 11, 5, 9);
    await repo.rescheduleOccurrence(occ[2].id, newStartUtc: moved); // exception

    await repo.updateSeries(
        taskId, draft(startMinute: 19 * 60, rule: RecurrenceRule(frequency: Frequency.daily)));

    occ = await liveOccurrences();
    final byDate = {for (final o in occ) o.occurrenceDate: o};
    expect(byDate['2026-11-03']!.status, 'done');
    expect(byDate['2026-11-03']!.scheduledStart, DateTime.utc(2026, 11, 3, 3)); // unchanged
    expect(byDate['2026-11-04']!.scheduledStart, DateTime.utc(2026, 11, 4, 16)); // 19:00
    expect(byDate['2026-11-05']!.scheduledStart, moved); // exception kept
    expect(byDate['2026-11-05']!.isException, isTrue);

    // Every future alarm matches the new plan; nothing stale left behind.
    for (final a in futureAlerts()) {
      final o = occ.firstWhere((o) => o.id == a.payload);
      expect(a.fireAtUtc, o.scheduledStart.subtract(const Duration(minutes: 10)));
    }
    expect(futureAlerts(), hasLength(14));
  });

  test('changing the rule drops dates that left the series', () async {
    final taskId = await repo.createTask(
        draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    await repo.updateSeries(taskId, draft(rule: RecurrenceRule.weekdays()));
    final occ = await liveOccurrences();
    expect(occ.every((o) => LocalDate.parse(o.occurrenceDate).weekday <= 5), isTrue);
    expect(futureAlerts(), hasLength(occ.length));

    // Switching back revives the dropped dates.
    await repo.updateSeries(taskId, draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    expect(await liveOccurrences(), hasLength(15));
    expect(futureAlerts(), hasLength(15));
  });

  test('changing reminders reschedules alarms', () async {
    final taskId = await repo.createTask(draft(reminders: [10]));
    await repo.updateSeries(taskId, draft(reminders: [0, 30]));
    expect(futureAlerts().map((a) => a.fireAtUtc).toList()..sort(),
        [DateTime.utc(2026, 11, 3, 14, 30), DateTime.utc(2026, 11, 3, 15)]);
  });

  test('deleting the series cancels alarms but keeps completed history', () async {
    final taskId = await repo.createTask(
        draft(startMinute: 6 * 60, rule: RecurrenceRule(frequency: Frequency.daily)));
    final first = (await liveOccurrences()).first;
    await repo.setStatus(first.id, OccurrenceStatus.done);
    await repo.deleteSeries(taskId);
    expect(futureAlerts(), isEmpty);
    final remaining = await liveOccurrences();
    expect(remaining.single.id, first.id);
    await repo.runMaintenance();
    expect(await liveOccurrences(), hasLength(1));
  });

  test('snooze adds one alert; completing the task cancels it', () async {
    await repo.createTask(draft(reminders: [0]));
    final occ = (await liveOccurrences()).single;
    now = DateTime.utc(2026, 11, 3, 15); // alert fired
    await scheduler.snooze(occ.id, const Duration(minutes: 10), now);
    expect(futureAlerts().single.fireAtUtc, DateTime.utc(2026, 11, 3, 15, 10));

    await repo.runMaintenance(); // snooze survives a resync
    expect(futureAlerts(), hasLength(1));

    await repo.setStatus(occ.id, OccurrenceStatus.done);
    expect(futureAlerts(), isEmpty);
  });

  test('caps registered alarms below the Android per-app limit, nearest first', () async {
    for (var i = 0; i < 40; i++) {
      await repo.createTask(draft(
        title: 'Task $i',
        startMinute: 9 * 60 + i,
        rule: RecurrenceRule(frequency: Frequency.daily),
      ));
    }
    // 40 tasks × 15 days = 600 wanted alarms.
    expect(futureAlerts(), hasLength(SchedulingPolicy.maxScheduledAlarmsAndroid));
    final latest = futureAlerts().map((a) => a.fireAtUtc).reduce((a, b) => a.isAfter(b) ? a : b);
    expect(latest.isBefore(DateTime.utc(2026, 11, 14)), isTrue);
  });

  test('watchDay returns the local day in start order', () async {
    await repo.createTask(draft(title: 'Late', startMinute: 20 * 60));
    await repo.createTask(draft(title: 'Early', startMinute: 1 * 60)); // 22:00Z prev day
    await repo.createTask(draft(title: 'Tomorrow', start: LocalDate(2026, 11, 4)));
    final day = await repo
        .watchDay(LocalDate(2026, 11, 3), tz.getLocation(zone))
        .first;
    expect(day.map((v) => v.task.title), ['Early', 'Late']);
  });

  group('watchRange (calendar)', () {
    tz.Location addis() => tz.getLocation(zone);

    test('projects a series beyond the stored 14-day window', () async {
      await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.weekly)));
      final december = await repo
          .watchRange(LocalDate(2026, 12, 1), LocalDate(2026, 12, 31), addis())
          .first;
      expect(december.map((v) => v.occurrence.occurrenceDate),
          ['2026-12-01', '2026-12-08', '2026-12-15', '2026-12-22', '2026-12-29']);
      expect(december.every((v) => v.isProjected), isTrue);
      expect(december.first.occurrence.scheduledStart, DateTime.utc(2026, 12, 1, 15));
      // Nothing beyond the window is stored.
      expect(await liveOccurrences(), hasLength(3));
    });

    test('joins stored and projected days without gaps or duplicates', () async {
      await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
      final views = await repo
          .watchRange(LocalDate(2026, 11, 10), LocalDate(2026, 11, 24), addis())
          .first;
      final dates = views.map((v) => v.occurrence.occurrenceDate).toList();
      expect(dates, hasLength(15));
      expect(dates.toSet(), hasLength(15));
      expect(views.where((v) => !v.isProjected).last.occurrence.occurrenceDate,
          '2026-11-17');
      expect(views.where((v) => v.isProjected).first.occurrence.occurrenceDate,
          '2026-11-18');
    });

    test('a deleted occurrence is not brought back by projection', () async {
      await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
      final nov5 = (await liveOccurrences())
          .firstWhere((o) => o.occurrenceDate == '2026-11-05');
      await repo.deleteOccurrence(nov5.id);
      final day = await repo.watchDay(LocalDate(2026, 11, 5), addis()).first;
      expect(day, isEmpty);
    });

    test('a one-off task months ahead shows on its day', () async {
      await repo.createTask(draft(title: 'Exam', start: LocalDate(2027, 2, 15)));
      final day = await repo.watchDay(LocalDate(2027, 2, 15), addis()).first;
      expect(day.single.task.title, 'Exam');
      expect(day.single.isProjected, isTrue);
    });

    test('does not invent history before the task existed', () async {
      await repo.createTask(draft(
          start: LocalDate(2026, 10, 1),
          rule: RecurrenceRule(frequency: Frequency.daily)));
      final past = await repo
          .watchRange(LocalDate(2026, 10, 20), LocalDate(2026, 10, 25), addis())
          .first;
      expect(past, isEmpty);
    });

    test('carries the task category', () async {
      await repo.ensureLocalUser(zone);
      final catId = await CategoryRepository(db)
          .create(name: 'Fitness', color: 0xFFE53935, icon: 'fitness');
      await repo.createTask(TaskDraft(
        title: 'Run',
        startDate: LocalDate(2026, 11, 3),
        startMinute: 18 * 60,
        timezone: zone,
        categoryId: catId,
      ));
      final view = (await repo.watchDay(LocalDate(2026, 11, 3), addis()).first).single;
      expect(view.category?.name, 'Fitness');
      expect((await repo.occurrenceById(view.occurrence.id))?.category?.color, 0xFFE53935);
    });
  });

  test('follows a device time-zone change for upcoming occurrences only', () async {
    final taskId = await repo.createTask(
        draft(startMinute: 6 * 60, rule: RecurrenceRule(frequency: Frequency.daily)));
    final first = (await liveOccurrences()).first; // today 06:00 Addis = 03:00Z
    await repo.setStatus(first.id, OccurrenceStatus.done);

    await repo.runMaintenance(deviceZone: 'Europe/London');

    final user = await db.select(db.users).getSingle();
    expect(user.timezone, 'Europe/London');
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
    expect(task.timezone, 'Europe/London');
    final byDate = {for (final o in await liveOccurrences()) o.occurrenceDate: o};
    expect(byDate['2026-11-03']!.scheduledStart, DateTime.utc(2026, 11, 3, 3)); // history kept
    expect(byDate['2026-11-04']!.scheduledStart, DateTime.utc(2026, 11, 4, 6)); // 06:00 London
    final next = gateway.forOccurrence(byDate['2026-11-04']!.id).single;
    expect(next.fireAtUtc, DateTime.utc(2026, 11, 4, 5, 50));
  });

  test('delete all data empties every table and cancels every alert', () async {
    await repo.createTask(draft(rule: RecurrenceRule(frequency: Frequency.daily)));
    await scheduler.snooze((await liveOccurrences()).first.id, const Duration(minutes: 5), now);
    expect(gateway.active, isNotEmpty);

    await repo.deleteAllData();

    expect(gateway.active, isEmpty);
    for (final table in db.allTables) {
      expect(await db.select(table).get(), isEmpty, reason: table.actualTableName);
    }
  });

  test('iOS cap keeps only the nearest 60 alerts', () async {
    final ios = TaskRepository(db, ReminderScheduler(db, gateway,
        maxAlarms: SchedulingPolicy.maxScheduledAlarmsIos), clock: () => now);
    for (var i = 0; i < 10; i++) {
      await ios.createTask(draft(
          title: 'T$i', startMinute: 9 * 60 + i, rule: RecurrenceRule(frequency: Frequency.daily)));
    }
    expect(futureAlerts(), hasLength(60)); // 150 wanted
  });

  test('snooze from the app', () async {
    await repo.createTask(draft(reminders: [0]));
    final occ = (await liveOccurrences()).single;
    await repo.snooze(occ.id, const Duration(minutes: 5));
    expect(gateway.forOccurrence(occ.id).map((a) => a.fireAtUtc),
        contains(now.add(const Duration(minutes: 5))));
  });
}
