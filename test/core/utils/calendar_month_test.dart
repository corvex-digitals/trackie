import 'package:flutter_test/flutter_test.dart';
import 'package:trackie/core/utils/calendar_month.dart';
import 'package:trackie/core/utils/local_date.dart';

void main() {
  group('Gregorian', () {
    final nov = CalendarMonth.containing(LocalDate(2026, 11, 12), ethiopian: false);

    test('spans the whole month', () {
      expect(nov.first, LocalDate(2026, 11, 1));
      expect(nov.length, 30);
      expect(nov.last, LocalDate(2026, 11, 30));
      expect(nov.dayOf(LocalDate(2026, 11, 12)), 12);
    });

    test('grid starts on Monday and pads to whole weeks', () {
      final cells = nov.gridCells();
      // 2026-11-01 is a Sunday: six empty cells before it.
      expect(cells.take(6), everyElement(isNull));
      expect(cells[6], LocalDate(2026, 11, 1));
      expect(cells.length % 7, 0);
      expect(cells.whereType<LocalDate>(), hasLength(30));
    });

    test('navigates across years', () {
      final dec = CalendarMonth.containing(LocalDate(2026, 12, 5), ethiopian: false);
      expect(dec.next.first, LocalDate(2027, 1, 1));
      expect(dec.next.previous, dec);
      expect(CalendarMonth.containing(LocalDate(2028, 2, 10), ethiopian: false).length, 29);
    });
  });

  group('Ethiopian', () {
    test('Tikimt 2019 starts on 2026-10-11 and has 30 days', () {
      final m = CalendarMonth.containing(LocalDate(2026, 11, 3), ethiopian: true);
      expect((m.year, m.month), (2019, 2));
      expect(m.first, LocalDate(2026, 10, 11));
      expect(m.length, 30);
      expect(m.dayOf(LocalDate(2026, 11, 3)), 24);
    });

    test('Pagume has 6 days in a leap year and 5 otherwise', () {
      final leap = CalendarMonth.containing(LocalDate(2027, 9, 6), ethiopian: true);
      expect((leap.year, leap.month, leap.length), (2019, 13, 6));
      final normal = CalendarMonth.containing(LocalDate(2025, 9, 6), ethiopian: true);
      expect((normal.year, normal.month, normal.length), (2017, 13, 5));
    });

    test('after Pagume comes Meskerem of the next year', () {
      final pagume = CalendarMonth.containing(LocalDate(2027, 9, 6), ethiopian: true);
      expect((pagume.next.year, pagume.next.month), (2020, 1));
      expect(pagume.next.first, pagume.last.addDays(1));
      expect(pagume.next.previous, pagume);
    });

    test('consecutive months tile the Gregorian timeline without gaps', () {
      var m = CalendarMonth.containing(LocalDate(2024, 1, 1), ethiopian: true);
      for (var i = 0; i < 40; i++) {
        final n = m.next;
        expect(n.first, m.last.addDays(1), reason: '${m.year}-${m.month}');
        m = n;
      }
    });
  });
}
