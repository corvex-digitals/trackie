import 'package:flutter_test/flutter_test.dart';
import 'package:trackie/core/utils/ethiopian_calendar.dart';
import 'package:trackie/core/utils/local_date.dart';

void main() {
  group('EthiopianDate.fromGregorian', () {
    final cases = {
      // Enkutatash (new year) falls on Sep 11, or Sep 12 in the Gregorian
      // year before a Gregorian leap year.
      LocalDate(2024, 9, 11): const EthiopianDate(2017, 1, 1),
      LocalDate(2023, 9, 12): const EthiopianDate(2016, 1, 1),
      LocalDate(2026, 9, 11): const EthiopianDate(2019, 1, 1),
      LocalDate(2026, 11, 3): const EthiopianDate(2019, 2, 24),
      // Last day of a leap year (2015 E.C.) is Pagume 6.
      LocalDate(2023, 9, 11): const EthiopianDate(2015, 13, 6),
      // Non-leap year ends on Pagume 5.
      LocalDate(2024, 9, 10): const EthiopianDate(2016, 13, 5),
      LocalDate(2000, 1, 1): const EthiopianDate(1992, 4, 22),
    };
    cases.forEach((gregorian, ethiopian) {
      test('$gregorian → $ethiopian', () {
        expect(EthiopianDate.fromGregorian(gregorian), ethiopian);
        expect(ethiopian.toGregorian(), gregorian);
      });
    });
  });

  test('round-trips every day from 1990 to 2040', () {
    var d = LocalDate(1990, 1, 1);
    final end = LocalDate(2040, 12, 31);
    EthiopianDate? previous;
    while (!d.isAfter(end)) {
      final e = EthiopianDate.fromGregorian(d);
      expect(e.toGregorian(), d, reason: '$d → $e');
      expect(e.day, inInclusiveRange(1, EthiopianDate.daysInMonth(e.year, e.month)));
      if (previous != null) {
        // Consecutive Gregorian days map to consecutive Ethiopian days.
        final rolledMonth = e.day == 1 && e.month != previous.month;
        expect(rolledMonth || e.day == previous.day + 1, isTrue, reason: '$d');
      }
      previous = e;
      d = d.addDays(1);
    }
  });

  test('rejects invalid dates', () {
    expect(() => const EthiopianDate(2016, 13, 6).toGregorian(), throwsArgumentError);
    expect(() => const EthiopianDate(2016, 14, 1).toGregorian(), throwsArgumentError);
    expect(() => const EthiopianDate(2016, 1, 31).toGregorian(), throwsArgumentError);
  });

  test('formats month names', () {
    const d = EthiopianDate(2019, 2, 24);
    expect(d.format(), 'Tikimt 24, 2019');
    expect(d.format(amharic: true), 'ጥቅምት 24, 2019');
  });
}
