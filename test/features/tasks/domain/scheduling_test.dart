import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:trackie/core/utils/local_date.dart';
import 'package:trackie/features/tasks/domain/scheduling.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('wallClockToUtc', () {
    test('Addis Ababa is UTC+3 all year', () {
      final addis = tz.getLocation('Africa/Addis_Ababa');
      expect(wallClockToUtc(LocalDate(2026, 11, 3), 9 * 60, addis),
          DateTime.utc(2026, 11, 3, 6));
      expect(wallClockToUtc(LocalDate(2026, 11, 3), 1 * 60 + 30, addis),
          DateTime.utc(2026, 11, 2, 22, 30));
    });

    test('keeps the wall-clock time across a DST change', () {
      final ny = tz.getLocation('America/New_York');
      // DST starts 2026-03-08.
      expect(wallClockToUtc(LocalDate(2026, 3, 7), 9 * 60, ny),
          DateTime.utc(2026, 3, 7, 14));
      expect(wallClockToUtc(LocalDate(2026, 3, 8), 9 * 60, ny),
          DateTime.utc(2026, 3, 8, 13));
    });

    test('localDateOf is the inverse at the day level', () {
      final addis = tz.getLocation('Africa/Addis_Ababa');
      expect(localDateOf(DateTime.utc(2026, 11, 2, 22), addis), LocalDate(2026, 11, 3));
      expect(localDateOf(DateTime.utc(2026, 11, 2, 20), addis), LocalDate(2026, 11, 2));
    });
  });

  test('reminder fires offset minutes before start', () {
    expect(reminderFireTime(DateTime.utc(2026, 11, 3, 6), 10),
        DateTime.utc(2026, 11, 3, 5, 50));
    expect(reminderFireTime(DateTime.utc(2026, 11, 3, 6), 0),
        DateTime.utc(2026, 11, 3, 6));
  });

  group('isOverdue (missed after grace period)', () {
    final end = DateTime.utc(2026, 11, 3, 7);

    test('not before end + 30 min', () {
      expect(
          isOverdue(
              status: OccurrenceStatus.pending,
              scheduledEndUtc: end,
              nowUtc: end.add(const Duration(minutes: 30))),
          isFalse);
    });

    test('after end + 30 min', () {
      expect(
          isOverdue(
              status: OccurrenceStatus.pending,
              scheduledEndUtc: end,
              nowUtc: end.add(const Duration(minutes: 31))),
          isTrue);
    });

    test('only pending occurrences become missed', () {
      for (final s in [OccurrenceStatus.done, OccurrenceStatus.skipped, OccurrenceStatus.missed]) {
        expect(
            isOverdue(status: s, scheduledEndUtc: end, nowUtc: end.add(const Duration(days: 1))),
            isFalse);
      }
    });
  });
}
