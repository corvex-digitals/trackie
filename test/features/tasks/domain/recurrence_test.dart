import 'package:flutter_test/flutter_test.dart';
import 'package:trackie/core/utils/local_date.dart';
import 'package:trackie/features/tasks/domain/recurrence.dart';

LocalDate d(String iso) => LocalDate.parse(iso);
List<String> isoList(List<LocalDate> dates) => dates.map((x) => x.toIso()).toList();

void main() {
  group('one-off task', () {
    test('occurs only on its start date', () {
      expect(
        isoList(occurrenceDates(start: d('2026-11-05'), from: d('2026-11-01'), to: d('2026-11-30'))),
        ['2026-11-05'],
      );
      expect(occurrenceDates(start: d('2026-10-05'), from: d('2026-11-01'), to: d('2026-11-30')), isEmpty);
    });
  });

  group('daily', () {
    test('every day within the window', () {
      final rule = RecurrenceRule(frequency: Frequency.daily);
      expect(
        isoList(rule.datesBetween(d('2026-11-01'), d('2026-11-03'), d('2026-11-06'))),
        ['2026-11-03', '2026-11-04', '2026-11-05', '2026-11-06'],
      );
    });

    test('custom interval counts from the start date, not the window', () {
      final rule = RecurrenceRule(frequency: Frequency.daily, interval: 3);
      expect(
        isoList(rule.datesBetween(d('2026-11-01'), d('2026-11-03'), d('2026-11-12'))),
        ['2026-11-04', '2026-11-07', '2026-11-10'],
      );
    });

    test('nothing before the start date', () {
      final rule = RecurrenceRule(frequency: Frequency.daily);
      expect(rule.datesBetween(d('2026-11-10'), d('2026-11-01'), d('2026-11-05')), isEmpty);
    });

    test('end date is inclusive', () {
      final rule = RecurrenceRule(frequency: Frequency.daily, endDate: d('2026-11-04'));
      expect(
        isoList(rule.datesBetween(d('2026-11-01'), d('2026-11-03'), d('2026-11-30'))),
        ['2026-11-03', '2026-11-04'],
      );
    });

    test('count includes occurrences before the window', () {
      final rule = RecurrenceRule(frequency: Frequency.daily, count: 3);
      expect(
        isoList(rule.datesBetween(d('2026-11-01'), d('2026-11-02'), d('2026-11-30'))),
        ['2026-11-02', '2026-11-03'],
      );
    });

    test('crosses month, year and leap day boundaries', () {
      final rule = RecurrenceRule(frequency: Frequency.daily);
      expect(
        isoList(rule.datesBetween(d('2028-02-27'), d('2028-02-28'), d('2028-03-01'))),
        ['2028-02-28', '2028-02-29', '2028-03-01'],
      );
    });
  });

  group('weekly', () {
    test('defaults to the weekday of the start date', () {
      // 2026-11-03 is a Tuesday.
      final rule = RecurrenceRule(frequency: Frequency.weekly);
      expect(
        isoList(rule.datesBetween(d('2026-11-03'), d('2026-11-01'), d('2026-11-30'))),
        ['2026-11-03', '2026-11-10', '2026-11-17', '2026-11-24'],
      );
    });

    test('weekdays preset skips the weekend', () {
      final rule = RecurrenceRule.weekdays();
      // Thu 2026-11-05 .. Tue 2026-11-10
      expect(
        isoList(rule.datesBetween(d('2026-11-05'), d('2026-11-05'), d('2026-11-10'))),
        ['2026-11-05', '2026-11-06', '2026-11-09', '2026-11-10'],
      );
    });

    test('every other week on Monday and Wednesday', () {
      final rule = RecurrenceRule(
          frequency: Frequency.weekly, interval: 2, byWeekdays: {1, 3});
      // Start Wed 2026-11-04: its week's Monday (11-02) is before the start.
      expect(
        isoList(rule.datesBetween(d('2026-11-04'), d('2026-11-01'), d('2026-11-30'))),
        ['2026-11-04', '2026-11-16', '2026-11-18', '2026-11-30'],
      );
    });

    test('count across weeks', () {
      final rule = RecurrenceRule(
          frequency: Frequency.weekly, byWeekdays: {2, 4}, count: 3);
      expect(
        isoList(rule.datesBetween(d('2026-11-03'), d('2026-11-01'), d('2026-12-31'))),
        ['2026-11-03', '2026-11-05', '2026-11-10'],
      );
    });
  });

  group('monthly', () {
    test('same day each month', () {
      final rule = RecurrenceRule(frequency: Frequency.monthly);
      expect(
        isoList(rule.datesBetween(d('2026-11-15'), d('2026-11-01'), d('2027-02-28'))),
        ['2026-11-15', '2026-12-15', '2027-01-15', '2027-02-15'],
      );
    });

    test('skips months that lack the day (RFC 5545)', () {
      final rule = RecurrenceRule(frequency: Frequency.monthly);
      expect(
        isoList(rule.datesBetween(d('2027-01-31'), d('2027-01-01'), d('2027-06-30'))),
        ['2027-01-31', '2027-03-31', '2027-05-31'],
      );
    });

    test('every 3 months', () {
      final rule = RecurrenceRule(frequency: Frequency.monthly, interval: 3);
      expect(
        isoList(rule.datesBetween(d('2026-01-10'), d('2026-01-01'), d('2026-12-31'))),
        ['2026-01-10', '2026-04-10', '2026-07-10', '2026-10-10'],
      );
    });
  });

  group('validation', () {
    test('rejects bad rules', () {
      expect(() => RecurrenceRule(frequency: Frequency.daily, interval: 0), throwsArgumentError);
      expect(() => RecurrenceRule(frequency: Frequency.daily, count: 0), throwsArgumentError);
      expect(() => RecurrenceRule(frequency: Frequency.weekly, byWeekdays: {8}), throwsArgumentError);
      expect(() => RecurrenceRule(frequency: Frequency.daily, byWeekdays: {1}), throwsArgumentError);
    });

    test('weekday csv round-trips', () {
      final rule = RecurrenceRule.weekdays();
      expect(rule.byWeekdaysCsv, '1,2,3,4,5');
      expect(RecurrenceRule.parseWeekdays(rule.byWeekdaysCsv), {1, 2, 3, 4, 5});
      expect(RecurrenceRule.parseWeekdays(null), isEmpty);
    });
  });
}
