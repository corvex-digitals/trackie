// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Trackie';

  @override
  String get tabToday => 'Today';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabInsights => 'Insights';

  @override
  String get tabSettings => 'Settings';

  @override
  String get newTask => 'New task';

  @override
  String get editTask => 'Edit task';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldDuration => 'Duration';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get fieldRepeat => 'Repeat';

  @override
  String get fieldReminders => 'Reminders';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get repeatNone => 'Does not repeat';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekdays => 'Weekdays (Mon–Fri)';

  @override
  String get repeatWeekly => 'Every week';

  @override
  String get repeatMonthly => 'Every month';

  @override
  String get reminderAtStart => 'At start';

  @override
  String reminderBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String get titleRequired => 'Enter a title';

  @override
  String get applyToWhich => 'Apply to which events?';

  @override
  String get onlyThisOne => 'Only this one';

  @override
  String get wholeSeries => 'All events in the series';

  @override
  String get actionDone => 'Done';

  @override
  String get actionSkip => 'Skip';

  @override
  String get statusDone => 'Done';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusMissed => 'Missed';

  @override
  String get markedDone => 'Marked done';

  @override
  String get markedSkipped => 'Skipped';

  @override
  String get emptyTodayTitle => 'Nothing planned today';

  @override
  String get emptyTodayBody => 'Tap + to add your first task.';

  @override
  String get nextUp => 'Next up';

  @override
  String get comingSoon => 'Coming in a later version';

  @override
  String get settingLanguage => 'Language';

  @override
  String get settingCalendar => 'Calendar';

  @override
  String get calendarGregorian => 'Gregorian';

  @override
  String get calendarEthiopian => 'Ethiopian';

  @override
  String get enableNotifications => 'Allow reminders';

  @override
  String get enableNotificationsBody =>
      'Trackie needs permission to alert you at the exact time of each task.';

  @override
  String get statusPending => 'Planned';

  @override
  String get actionSnooze => 'Snooze';

  @override
  String snoozeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String snoozedFor(int minutes) {
    return 'Reminder snoozed for $minutes min';
  }

  @override
  String get actionReschedule => 'Reschedule';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionReset => 'Mark as not done';

  @override
  String rescheduled(String time) {
    return 'Moved to $time';
  }

  @override
  String get projectedNote =>
      'This is a future repeat of the series. Edit the series to change it.';

  @override
  String get editSeries => 'Edit series';

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get fieldCategory => 'Category';

  @override
  String get categoryNone => 'No category';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewMonth => 'Month';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get goToToday => 'Today';

  @override
  String get noTasks => 'No tasks';

  @override
  String moreCount(int count) {
    return '+$count more';
  }

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldColor => 'Colour';

  @override
  String get fieldIcon => 'Icon';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get noCategories => 'No categories yet. Tap + to add one.';

  @override
  String deleteCategoryTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteCategoryBody => 'Its tasks will be kept without a category.';

  @override
  String get sectionReminders => 'Reminders';

  @override
  String get sectionGeneral => 'General';

  @override
  String get sectionData => 'Your data';

  @override
  String get remindersReady => 'Reminders are set up to arrive on time.';

  @override
  String get remindersAttention =>
      'Some settings may delay or block your reminders.';

  @override
  String get permNotificationsTitle => 'Notifications';

  @override
  String get permNotificationsBody => 'Needed to show reminders.';

  @override
  String get permExactTitle => 'Alarms & reminders';

  @override
  String get permExactBody => 'Lets reminders arrive on the exact minute.';

  @override
  String get permBatteryTitle => 'Battery: unrestricted';

  @override
  String get permBatteryBody =>
      'Some phones stop reminders to save battery. In the list, set Trackie to \"Unrestricted\" or \"Don\'t optimise\".';

  @override
  String get autostartTitle => 'Auto-start';

  @override
  String autostartBody(String maker) {
    return 'On $maker phones, also open the app settings and allow Trackie to auto-start and run in the background.';
  }

  @override
  String get permAllow => 'Allow';

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permGranted => 'Allowed';

  @override
  String get settingDefaultReminder => 'Default reminder';

  @override
  String get settingTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get deleteAllData => 'Delete all data';

  @override
  String get deleteAllDataBody =>
      'Removes every task, its history and your settings from this phone. This can\'t be undone.';

  @override
  String get deleteEverything => 'Delete everything';

  @override
  String get onboardingWelcomeTitle => 'Plan your day. Get reminded on time.';

  @override
  String get onboardingWelcomeBody =>
      'Choose your language and calendar. You can change them later in Settings.';

  @override
  String get onboardingRemindersTitle => 'Make reminders reliable';

  @override
  String get onboardingRemindersBody =>
      'Trackie hands each reminder to your phone so it fires even when the app is closed. Allow these so nothing is missed.';

  @override
  String get continueButton => 'Continue';

  @override
  String get getStarted => 'Get started';

  @override
  String get back => 'Back';

  @override
  String semanticsOccurrence(String title, String time, String status) {
    return '$title, $time, $status';
  }
}
