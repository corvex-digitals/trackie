import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'calendar_month.dart';
import 'ethiopian_calendar.dart';
import 'local_date.dart';

/// Formats a date in the user's chosen calendar (FR-20, NFR-11).
String formatLongDate(BuildContext context, LocalDate date,
    {required bool ethiopian}) {
  final locale = Localizations.localeOf(context).languageCode;
  if (ethiopian) {
    final weekday = DateFormat.EEEE(locale)
        .format(DateTime(date.year, date.month, date.day));
    return '$weekday, ${EthiopianDate.fromGregorian(date).format(amharic: locale == 'am')}';
  }
  return DateFormat.yMMMMEEEEd(locale)
      .format(DateTime(date.year, date.month, date.day));
}

String formatMinuteOfDay(BuildContext context, int minute) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

String formatTime(BuildContext context, DateTime local) =>
    formatMinuteOfDay(context, local.hour * 60 + local.minute);

/// "Nov 12" / "Hidar 3" (or Amharic month name) without the year.
String formatShortDate(BuildContext context, LocalDate date,
    {required bool ethiopian}) {
  final locale = Localizations.localeOf(context).languageCode;
  if (ethiopian) {
    final e = EthiopianDate.fromGregorian(date);
    final names =
        locale == 'am' ? EthiopianDate.monthNamesAm : EthiopianDate.monthNamesEn;
    return '${names[e.month - 1]} ${e.day}';
  }
  return DateFormat.MMMd(locale).format(DateTime(date.year, date.month, date.day));
}

/// Month and year title for the month view.
String formatMonthTitle(BuildContext context, CalendarMonth month) {
  final locale = Localizations.localeOf(context).languageCode;
  if (month.ethiopian) {
    final names =
        locale == 'am' ? EthiopianDate.monthNamesAm : EthiopianDate.monthNamesEn;
    return '${names[month.month - 1]} ${month.year}';
  }
  return DateFormat.yMMMM(locale).format(DateTime(month.year, month.month));
}

/// Narrow weekday labels Monday..Sunday in the current locale.
List<String> weekdayInitials(BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  final monday = DateTime(2024, 1, 1); // a Monday
  return [
    for (var i = 0; i < 7; i++)
      DateFormat.E(locale).format(monday.add(Duration(days: i))),
  ];
}
