import 'ethiopian_calendar.dart';
import 'local_date.dart';

/// A month in either the Gregorian or the Ethiopian calendar, as a span of
/// Gregorian dates, for the month view (FR-12, FR-20).
class CalendarMonth {
  CalendarMonth._(this.year, this.month, this.ethiopian, this.first, this.length);

  /// The month containing [date].
  factory CalendarMonth.containing(LocalDate date, {required bool ethiopian}) {
    if (ethiopian) {
      final e = EthiopianDate.fromGregorian(date);
      return CalendarMonth._ethiopian(e.year, e.month);
    }
    return CalendarMonth._gregorian(date.year, date.month);
  }

  factory CalendarMonth._gregorian(int year, int month) {
    final first = LocalDate(year, month, 1);
    final next = month == 12 ? LocalDate(year + 1, 1, 1) : LocalDate(year, month + 1, 1);
    return CalendarMonth._(year, month, false, first, first.daysUntil(next));
  }

  factory CalendarMonth._ethiopian(int year, int month) => CalendarMonth._(
        year,
        month,
        true,
        EthiopianDate(year, month, 1).toGregorian(),
        EthiopianDate.daysInMonth(year, month),
      );

  /// Year and month number in this month's own calendar (Ethiopian months
  /// run 1..13, the 13th being Pagume).
  final int year;
  final int month;
  final bool ethiopian;

  /// Gregorian date of the month's first day.
  final LocalDate first;
  final int length;

  LocalDate get last => first.addDays(length - 1);

  bool contains(LocalDate d) => !d.isBefore(first) && !d.isAfter(last);

  /// Day number of [d] within this month (1-based).
  int dayOf(LocalDate d) => first.daysUntil(d) + 1;

  CalendarMonth get next => ethiopian
      ? (month == 13
          ? CalendarMonth._ethiopian(year + 1, 1)
          : CalendarMonth._ethiopian(year, month + 1))
      : (month == 12
          ? CalendarMonth._gregorian(year + 1, 1)
          : CalendarMonth._gregorian(year, month + 1));

  CalendarMonth get previous => ethiopian
      ? (month == 1
          ? CalendarMonth._ethiopian(year - 1, 13)
          : CalendarMonth._ethiopian(year, month - 1))
      : (month == 1
          ? CalendarMonth._gregorian(year - 1, 12)
          : CalendarMonth._gregorian(year, month - 1));

  /// Grid cells in weeks starting on Monday: leading/trailing nulls pad the
  /// first and last week. Length is a multiple of 7.
  List<LocalDate?> gridCells() {
    final lead = first.weekday - 1;
    final cells = <LocalDate?>[
      for (var i = 0; i < lead; i++) null,
      for (var i = 0; i < length; i++) first.addDays(i),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth &&
      other.ethiopian == ethiopian &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(ethiopian, year, month);
}
