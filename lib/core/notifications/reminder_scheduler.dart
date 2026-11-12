import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/tasks/domain/scheduling.dart';
import '../database/app_database.dart';
import 'notification_gateway.dart';

/// Keeps OS alarms in step with the database (section 7, "Keeping alarms
/// alive").
///
/// [resync] is idempotent: it computes the alerts that *should* exist for
/// pending occurrences, compares them with `scheduled_notifications`, and
/// cancels or registers only the difference. Call it after every change, on
/// app start, after a reboot or time-zone change, and when the window rolls.
class ReminderScheduler {
  ReminderScheduler(
    this._db,
    this._gateway, {
    this.maxAlarms = SchedulingPolicy.maxScheduledAlarmsAndroid,
  });

  final AppDatabase _db;
  final NotificationGateway _gateway;

  /// Most alerts registered with the OS at once (platform limit).
  final int maxAlarms;

  /// Cancels every registered alert and registers them again, e.g. after a
  /// language change so the notification text is re-rendered.
  Future<void> rebuildAll(DateTime nowUtc) async {
    await _cancelAllScheduled();
    await resync(nowUtc);
  }

  /// Cancels every alert and forgets them (used when deleting all data).
  Future<void> cancelAll() async {
    await _gateway.cancelAll();
    await _db.delete(_db.scheduledNotifications).go();
  }

  Future<void> _cancelAllScheduled() => _db.transaction(() async {
        final rows = await (_db.select(_db.scheduledNotifications)
              ..where((n) => n.state.equals('scheduled')))
            .get();
        for (final n in rows) {
          await _cancel(n);
        }
      });

  Future<void> resync(DateTime nowUtc) => _db.transaction(() async {
        final desired = await _desiredAlerts(nowUtc);
        final existing = await (_db.select(_db.scheduledNotifications)
              ..where((n) => n.state.equals('scheduled')))
            .get();

        final pendingIds = await _pendingOccurrenceIds(
            existing.where((n) => n.reminderId == null).map((n) => n.occurrenceId));

        for (final n in existing) {
          if (!n.fireAt.isAfter(nowUtc)) {
            await _setState(n.osNotificationId, 'fired');
            continue;
          }
          if (n.reminderId == null) {
            // A snoozed alert: keep it while its occurrence is still pending.
            if (!pendingIds.contains(n.occurrenceId)) await _cancel(n);
            continue;
          }
          final want = desired.remove(_key(n.occurrenceId, n.reminderId!));
          if (want == null || !want.fireAtUtc.isAtSameMomentAs(n.fireAt)) {
            await _cancel(n);
            if (want != null) desired[want.key] = want;
          }
        }

        var nextId = await _nextOsId();
        for (final alert in desired.values) {
          final id = nextId++;
          await _db.into(_db.scheduledNotifications).insert(
                ScheduledNotificationsCompanion.insert(
                  osNotificationId: Value(id),
                  occurrenceId: alert.occurrenceId,
                  reminderId: Value(alert.reminderId),
                  fireAt: alert.fireAtUtc,
                ),
              );
          await _gateway.schedule(
            id: id,
            fireAtUtc: alert.fireAtUtc,
            title: alert.title,
            body: alert.body,
            payload: alert.occurrenceId,
          );
        }

        await _pruneHistory(nowUtc);
      });

  /// Re-alerts in [delay] (FR-09). Logged as `snoozed`.
  Future<void> snooze(String occurrenceId, Duration delay, DateTime nowUtc) =>
      _db.transaction(() async {
        final row = await (_db.select(_db.occurrences).join([
          innerJoin(_db.tasks, _db.tasks.id.equalsExp(_db.occurrences.taskId)),
        ])
              ..where(_db.occurrences.id.equals(occurrenceId)))
            .getSingleOrNull();
        if (row == null) return;
        final task = row.readTable(_db.tasks);
        final fireAt = nowUtc.add(delay);
        final id = await _nextOsId();

        await _db.into(_db.scheduledNotifications).insert(
              ScheduledNotificationsCompanion.insert(
                osNotificationId: Value(id),
                occurrenceId: occurrenceId,
                fireAt: fireAt,
              ),
            );
        await _db.into(_db.activityLogs).insert(ActivityLogsCompanion.insert(
              occurrenceId: occurrenceId,
              action: 'snoozed',
              at: nowUtc,
              note: Value('${delay.inMinutes} min'),
            ));
        final strings = await _strings();
        await _gateway.schedule(
          id: id,
          fireAtUtc: fireAt,
          title: task.title,
          body: strings.snoozed,
          payload: occurrenceId,
        );
      });

  Future<Map<String, _Alert>> _desiredAlerts(DateTime nowUtc) async {
    final o = _db.occurrences;
    final horizon =
        nowUtc.add(const Duration(days: SchedulingPolicy.windowDays + 1));
    final query = _db.select(o).join([
      innerJoin(_db.tasks, _db.tasks.id.equalsExp(o.taskId)),
      innerJoin(_db.reminders, _db.reminders.taskId.equalsExp(o.taskId)),
    ])
      ..where(o.status.equals(OccurrenceStatus.pending.name) &
          o.deletedAt.isNull() &
          _db.tasks.deletedAt.isNull() &
          _db.reminders.deletedAt.isNull() &
          _db.reminders.type.equals('time') &
          o.scheduledStart.isBiggerThanValue(nowUtc) &
          o.scheduledStart.isSmallerOrEqualValue(horizon));

    final strings = await _strings();
    final alerts = <_Alert>[];
    for (final row in await query.get()) {
      final occ = row.readTable(o);
      final task = row.readTable(_db.tasks);
      final reminder = row.readTable(_db.reminders);
      final fireAt = reminderFireTime(occ.scheduledStart, reminder.offsetMin);
      if (!fireAt.isAfter(nowUtc)) continue;

      final local = tz.TZDateTime.from(occ.scheduledStart, tz.getLocation(task.timezone));
      final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      alerts.add(_Alert(
        occurrenceId: occ.id,
        reminderId: reminder.id,
        fireAtUtc: fireAt,
        title: task.title,
        body: reminder.offsetMin == 0
            ? strings.startingNow(time)
            : strings.startsIn(reminder.offsetMin, time),
      ));
    }

    // Nearest first, capped below Android's per-app alarm limit.
    alerts.sort((a, b) => a.fireAtUtc.compareTo(b.fireAtUtc));
    return {
      for (final a in alerts.take(maxAlarms)) a.key: a,
    };
  }

  Future<Set<String>> _pendingOccurrenceIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    final rows = await (_db.select(_db.occurrences)
          ..where((o) =>
              o.id.isIn(list) &
              o.deletedAt.isNull() &
              o.status.equals(OccurrenceStatus.pending.name)))
        .get();
    return rows.map((r) => r.id).toSet();
  }

  Future<void> _cancel(ScheduledNotification n) async {
    await _gateway.cancel(n.osNotificationId);
    await _setState(n.osNotificationId, 'cancelled');
  }

  Future<void> _setState(int osId, String state) =>
      (_db.update(_db.scheduledNotifications)
            ..where((n) => n.osNotificationId.equals(osId)))
          .write(ScheduledNotificationsCompanion(state: Value(state)));

  /// OS notification ids must fit in a 32-bit signed int.
  Future<int> _nextOsId() async {
    final max = _db.scheduledNotifications.osNotificationId.max();
    final current = await (_db.selectOnly(_db.scheduledNotifications)
          ..addColumns([max]))
        .map((r) => r.read(max))
        .getSingle();
    final next = (current ?? 0) + 1;
    return next >= 0x7fffffff ? 1 : next;
  }

  Future<void> _pruneHistory(DateTime nowUtc) =>
      (_db.delete(_db.scheduledNotifications)
            ..where((n) =>
                n.state.isNotValue('scheduled') &
                n.fireAt.isSmallerThanValue(
                    nowUtc.subtract(const Duration(days: 7)))))
          .go();

  Future<_Strings> _strings() async {
    final user = await (_db.select(_db.users)..limit(1)).getSingleOrNull();
    return user?.language == 'am' ? const _Strings.am() : const _Strings.en();
  }

  static String _key(String occurrenceId, String reminderId) =>
      '$occurrenceId|$reminderId';
}

class _Alert {
  _Alert({
    required this.occurrenceId,
    required this.reminderId,
    required this.fireAtUtc,
    required this.title,
    required this.body,
  });

  final String occurrenceId;
  final String reminderId;
  final DateTime fireAtUtc;
  final String title;
  final String body;

  String get key => ReminderScheduler._key(occurrenceId, reminderId);
}

/// Notification text is built outside the widget tree (possibly in a
/// background isolate), so it cannot use AppLocalizations.
class _Strings {
  const _Strings.en() : _am = false;
  const _Strings.am() : _am = true;
  final bool _am;

  String startingNow(String time) => _am ? 'አሁን ይጀምራል · $time' : 'Starting now · $time';
  String startsIn(int min, String time) =>
      _am ? 'በ$min ደቂቃ ውስጥ · $time' : 'In $min min · $time';
  String get snoozed => _am ? 'የተራዘመ ማስታወሻ' : 'Snoozed reminder';
}
