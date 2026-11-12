import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/local_date.dart';

/// Status of one dated occurrence (FR-14).
enum OccurrenceStatus { pending, done, skipped, missed }

/// Time policy shared by the planner, the alarm scheduler and the UI.
abstract final class SchedulingPolicy {
  /// How far ahead occurrences are materialised (design note: today + 14 days).
  static const windowDays = 14;

  /// A pending occurrence becomes "missed" this long after it was due to end.
  static const missedGrace = Duration(minutes: 30);

  /// Android silently drops alarms beyond ~500 per app. Stay well below that
  /// and register the nearest alerts first; the rest are registered as the
  /// window rolls forward.
  static const maxScheduledAlarmsAndroid = 400;

  /// iOS keeps only the 64 soonest pending local notifications per app.
  /// Leave headroom for snoozed alerts.
  static const maxScheduledAlarmsIos = 60;

  /// How often the Android background job re-runs maintenance (missed
  /// marking, window extension, time-zone check, alarm resync). The first run
  /// is at local midnight.
  static const maintenanceInterval = Duration(hours: 6);

  /// Minutes-before-start choices offered for reminders.
  static const reminderChoices = [0, 5, 10, 15, 30, 60];

  static const snoozeOptions = [
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
  ];
}

/// Converts a wall-clock time on [date] in [location] to a UTC instant.
///
/// [startMinute] is minutes since local midnight. Times that do not exist
/// (skipped by a DST jump) are resolved by the timezone package to the
/// following valid instant.
DateTime wallClockToUtc(LocalDate date, int startMinute, tz.Location location) {
  return tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day,
    startMinute ~/ 60,
    startMinute % 60,
  ).toUtc();
}

/// The local calendar date of [instant] in [location].
LocalDate localDateOf(DateTime instant, tz.Location location) =>
    LocalDate.fromDateTime(tz.TZDateTime.from(instant, location));

/// When an alert for an occurrence starting at [startUtc] should fire.
DateTime reminderFireTime(DateTime startUtc, int offsetMinutes) =>
    startUtc.subtract(Duration(minutes: offsetMinutes));

/// Whether a pending occurrence should be automatically marked missed.
bool isOverdue({
  required OccurrenceStatus status,
  required DateTime scheduledEndUtc,
  required DateTime nowUtc,
  Duration grace = SchedulingPolicy.missedGrace,
}) =>
    status == OccurrenceStatus.pending &&
    nowUtc.isAfter(scheduledEndUtc.add(grace));
