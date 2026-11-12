import 'local_date.dart';

/// A date in the Ethiopian (Ge'ez) calendar, Amete Mihret era.
///
/// The year has 12 months of 30 days, then Pagume with 5 days (6 in a leap
/// year). An Ethiopian year Y is a leap year when Y % 4 == 3. Conversion goes
/// through the Julian Day Number, so it is exact for any date.
class EthiopianDate {
  const EthiopianDate(this.year, this.month, this.day);

  final int year;
  final int month; // 1..13 (13 = Pagume)
  final int day; // 1..30 (1..5/6 for Pagume)

  /// JDN of the day before 1 Meskerem, year 1 minus 365 days (Beyene–Kudlek).
  static const int _epoch = 1723856;

  static bool isLeapYear(int year) => year % 4 == 3;

  static int daysInMonth(int year, int month) {
    if (month < 13) return 30;
    return isLeapYear(year) ? 6 : 5;
  }

  factory EthiopianDate.fromGregorian(LocalDate date) {
    final jdn = date.julianDay;
    final r = (jdn - _epoch) % 1461;
    final n = r % 365 + 365 * (r ~/ 1460);
    final year = 4 * ((jdn - _epoch) ~/ 1461) + r ~/ 365 - r ~/ 1460;
    return EthiopianDate(year, n ~/ 30 + 1, n % 30 + 1);
  }

  LocalDate toGregorian() {
    if (month < 1 || month > 13 || day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError('Invalid Ethiopian date $year-$month-$day');
    }
    final jdn = _epoch + 365 + 365 * (year - 1) + year ~/ 4 + 30 * month + day - 31;
    return LocalDate(1970, 1, 1).addDays(jdn - 2440588);
  }

  static const monthNamesAm = [
    'መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', //
    'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜን',
  ];

  static const monthNamesEn = [
    'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', //
    'Megabit', 'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume',
  ];

  String format({bool amharic = false}) {
    final names = amharic ? monthNamesAm : monthNamesEn;
    return '${names[month - 1]} $day, $year';
  }

  @override
  bool operator ==(Object other) =>
      other is EthiopianDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'EthiopianDate($year-$month-$day)';
}
