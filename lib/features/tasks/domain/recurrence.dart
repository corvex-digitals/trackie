import '../../../core/utils/local_date.dart';

enum Frequency { daily, weekly, monthly }

/// How a task repeats (FR-04). Covers the presets in the spec:
///
/// * daily           → `RecurrenceRule(frequency: daily)`
/// * weekdays        → `RecurrenceRule.weekdays()`
/// * weekly          → `RecurrenceRule(frequency: weekly)` (on the start's weekday)
/// * monthly         → `RecurrenceRule(frequency: monthly)` (on the start's day of month)
/// * custom interval → any of the above with `interval > 1`
///
/// The series ends at [endDate] (inclusive) or after [count] occurrences,
/// whichever comes first; with neither it repeats indefinitely.
class RecurrenceRule {
  RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    Set<int> byWeekdays = const {},
    this.endDate,
    this.count,
  }) : byWeekdays = Set.unmodifiable(byWeekdays) {
    if (interval < 1) throw ArgumentError.value(interval, 'interval', 'must be >= 1');
    if (count != null && count! < 1) throw ArgumentError.value(count, 'count', 'must be >= 1');
    if (byWeekdays.any((d) => d < 1 || d > 7)) {
      throw ArgumentError.value(byWeekdays, 'byWeekdays', 'ISO weekdays 1..7');
    }
    if (byWeekdays.isNotEmpty && frequency != Frequency.weekly) {
      throw ArgumentError('byWeekdays is only valid for weekly rules');
    }
  }

  factory RecurrenceRule.weekdays({LocalDate? endDate}) => RecurrenceRule(
        frequency: Frequency.weekly,
        byWeekdays: const {1, 2, 3, 4, 5},
        endDate: endDate,
      );

  final Frequency frequency;
  final int interval;

  /// ISO weekdays (1 = Monday). Empty means "the weekday of the start date".
  final Set<int> byWeekdays;
  final LocalDate? endDate;
  final int? count;

  /// Dates of the series that starts on [start] and fall within
  /// [from]..[to] (both inclusive), in ascending order.
  ///
  /// Only ever expands a bounded window — callers must never ask for an
  /// unbounded range (see "rolling window" in the design notes).
  List<LocalDate> datesBetween(LocalDate start, LocalDate from, LocalDate to) {
    final result = <LocalDate>[];
    var last = to;
    if (endDate != null && endDate!.isBefore(last)) last = endDate!;
    if (last.isBefore(start) || last.isBefore(from)) return result;

    var produced = 0;
    for (final date in _iterate(start)) {
      if (date.isAfter(last)) break;
      produced++;
      if (!date.isBefore(from)) result.add(date);
      if (count != null && produced >= count!) break;
    }
    return result;
  }

  /// Every date of the series, in order, starting at [start]. Infinite unless
  /// the caller stops consuming it.
  Iterable<LocalDate> _iterate(LocalDate start) sync* {
    switch (frequency) {
      case Frequency.daily:
        for (var d = start;; d = d.addDays(interval)) {
          yield d;
        }
      case Frequency.weekly:
        final days = byWeekdays.isEmpty ? {start.weekday} : byWeekdays;
        final sorted = days.toList()..sort();
        for (var week = start.startOfWeek;; week = week.addDays(7 * interval)) {
          for (final wd in sorted) {
            final d = week.addDays(wd - 1);
            if (!d.isBefore(start)) yield d;
          }
        }
      case Frequency.monthly:
        // Months without the start's day (e.g. the 31st) are skipped.
        for (var i = 0;; i += interval) {
          final d = start.addMonths(i);
          if (d != null) yield d;
        }
    }
  }

  RecurrenceRule copyWith({LocalDate? endDate, int? count}) => RecurrenceRule(
        frequency: frequency,
        interval: interval,
        byWeekdays: byWeekdays,
        endDate: endDate ?? this.endDate,
        count: count ?? this.count,
      );

  /// Compact storage format for the `by_weekdays` column: "1,2,3".
  String get byWeekdaysCsv => (byWeekdays.toList()..sort()).join(',');

  static Set<int> parseWeekdays(String? csv) => csv == null || csv.isEmpty
      ? const {}
      : csv.split(',').map(int.parse).toSet();
}

/// The dates a task occurs on within [from]..[to]. A one-off task (no rule)
/// occurs only on its start date.
List<LocalDate> occurrenceDates({
  required LocalDate start,
  RecurrenceRule? rule,
  required LocalDate from,
  required LocalDate to,
}) {
  if (rule == null) {
    return (start.isBefore(from) || start.isAfter(to)) ? const [] : [start];
  }
  return rule.datesBetween(start, from, to);
}
