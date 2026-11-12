/// A calendar date with no time or time zone ("2026-11-03").
///
/// Recurrence is computed on calendar dates in the user's own time zone, and
/// converted to UTC instants only when an occurrence is materialised. Keeping
/// dates separate from instants avoids off-by-one-day bugs around midnight and
/// DST changes.
class LocalDate implements Comparable<LocalDate> {
  LocalDate(int year, int month, int day)
      : _utc = DateTime.utc(year, month, day) {
    if (_utc.year != year || _utc.month != month || _utc.day != day) {
      throw ArgumentError('Invalid date $year-$month-$day');
    }
  }

  LocalDate._(this._utc);

  /// Today's date in the device's local time zone.
  factory LocalDate.today() => LocalDate.fromDateTime(DateTime.now());

  /// Takes the year/month/day fields of [dt] as they are (no zone conversion).
  factory LocalDate.fromDateTime(DateTime dt) =>
      LocalDate._(DateTime.utc(dt.year, dt.month, dt.day));

  /// Parses `YYYY-MM-DD`.
  factory LocalDate.parse(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) throw FormatException('Expected YYYY-MM-DD', iso);
    return LocalDate(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  final DateTime _utc;

  int get year => _utc.year;
  int get month => _utc.month;
  int get day => _utc.day;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => _utc.weekday;

  /// Days since 1970-01-01.
  int get epochDay => _utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// Julian Day Number (used for calendar conversions).
  int get julianDay => epochDay + 2440588;

  LocalDate addDays(int days) => LocalDate._(
      DateTime.utc(_utc.year, _utc.month, _utc.day + days));

  /// Adds whole months. Returns null when the day does not exist in the target
  /// month (e.g. Jan 31 + 1 month), matching RFC 5545 behaviour of skipping.
  LocalDate? addMonths(int months) {
    final target = DateTime.utc(_utc.year, _utc.month + months, 1);
    final candidate = DateTime.utc(target.year, target.month, _utc.day);
    if (candidate.month != target.month) return null;
    return LocalDate._(candidate);
  }

  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  /// Monday of the ISO week containing this date.
  LocalDate get startOfWeek => addDays(1 - weekday);

  bool isBefore(LocalDate other) => epochDay < other.epochDay;
  bool isAfter(LocalDate other) => epochDay > other.epochDay;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  @override
  String toString() => toIso();
}
