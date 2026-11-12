import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('am'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Trackie'**
  String get appTitle;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @tabInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get tabInsights;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get editTask;

  /// No description provided for @fieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fieldTitle;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @fieldDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get fieldDuration;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @fieldPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get fieldPriority;

  /// No description provided for @fieldRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get fieldRepeat;

  /// No description provided for @fieldReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get fieldReminders;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'Does not repeat'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatDaily;

  /// No description provided for @repeatWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays (Mon–Fri)'**
  String get repeatWeekdays;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeatMonthly;

  /// No description provided for @reminderAtStart.
  ///
  /// In en, this message translates to:
  /// **'At start'**
  String get reminderAtStart;

  /// No description provided for @reminderBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String reminderBefore(int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get titleRequired;

  /// No description provided for @applyToWhich.
  ///
  /// In en, this message translates to:
  /// **'Apply to which events?'**
  String get applyToWhich;

  /// No description provided for @onlyThisOne.
  ///
  /// In en, this message translates to:
  /// **'Only this one'**
  String get onlyThisOne;

  /// No description provided for @wholeSeries.
  ///
  /// In en, this message translates to:
  /// **'All events in the series'**
  String get wholeSeries;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @markedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked done'**
  String get markedDone;

  /// No description provided for @markedSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get markedSkipped;

  /// No description provided for @emptyTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing planned today'**
  String get emptyTodayTitle;

  /// No description provided for @emptyTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first task.'**
  String get emptyTodayBody;

  /// No description provided for @nextUp.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get nextUp;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming in a later version'**
  String get comingSoon;

  /// No description provided for @settingLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingLanguage;

  /// No description provided for @settingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get settingCalendar;

  /// No description provided for @calendarGregorian.
  ///
  /// In en, this message translates to:
  /// **'Gregorian'**
  String get calendarGregorian;

  /// No description provided for @calendarEthiopian.
  ///
  /// In en, this message translates to:
  /// **'Ethiopian'**
  String get calendarEthiopian;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow reminders'**
  String get enableNotifications;

  /// No description provided for @enableNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Trackie needs permission to alert you at the exact time of each task.'**
  String get enableNotificationsBody;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusPending;

  /// No description provided for @actionSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get actionSnooze;

  /// No description provided for @snoozeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String snoozeMinutes(int minutes);

  /// No description provided for @snoozedFor.
  ///
  /// In en, this message translates to:
  /// **'Reminder snoozed for {minutes} min'**
  String snoozedFor(int minutes);

  /// No description provided for @actionReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get actionReschedule;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done'**
  String get actionReset;

  /// No description provided for @rescheduled.
  ///
  /// In en, this message translates to:
  /// **'Moved to {time}'**
  String rescheduled(String time);

  /// No description provided for @projectedNote.
  ///
  /// In en, this message translates to:
  /// **'This is a future repeat of the series. Edit the series to change it.'**
  String get projectedNote;

  /// No description provided for @editSeries.
  ///
  /// In en, this message translates to:
  /// **'Edit series'**
  String get editSeries;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String timeRange(String start, String end);

  /// No description provided for @fieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fieldCategory;

  /// No description provided for @categoryNone.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get categoryNone;

  /// No description provided for @viewWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get viewWeek;

  /// No description provided for @viewMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get viewMonth;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @goToToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get goToToday;

  /// No description provided for @noTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get noTasks;

  /// No description provided for @moreCount.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String moreCount(int count);

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get fieldColor;

  /// No description provided for @fieldIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get fieldIcon;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet. Tap + to add one.'**
  String get noCategories;

  /// No description provided for @deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteCategoryTitle(String name);

  /// No description provided for @deleteCategoryBody.
  ///
  /// In en, this message translates to:
  /// **'Its tasks will be kept without a category.'**
  String get deleteCategoryBody;

  /// No description provided for @sectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get sectionReminders;

  /// No description provided for @sectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get sectionGeneral;

  /// No description provided for @sectionData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get sectionData;

  /// No description provided for @remindersReady.
  ///
  /// In en, this message translates to:
  /// **'Reminders are set up to arrive on time.'**
  String get remindersReady;

  /// No description provided for @remindersAttention.
  ///
  /// In en, this message translates to:
  /// **'Some settings may delay or block your reminders.'**
  String get remindersAttention;

  /// No description provided for @permNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permNotificationsTitle;

  /// No description provided for @permNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Needed to show reminders.'**
  String get permNotificationsBody;

  /// No description provided for @permExactTitle.
  ///
  /// In en, this message translates to:
  /// **'Alarms & reminders'**
  String get permExactTitle;

  /// No description provided for @permExactBody.
  ///
  /// In en, this message translates to:
  /// **'Lets reminders arrive on the exact minute.'**
  String get permExactBody;

  /// No description provided for @permBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery: unrestricted'**
  String get permBatteryTitle;

  /// No description provided for @permBatteryBody.
  ///
  /// In en, this message translates to:
  /// **'Some phones stop reminders to save battery. In the list, set Trackie to \"Unrestricted\" or \"Don\'t optimise\".'**
  String get permBatteryBody;

  /// No description provided for @autostartTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-start'**
  String get autostartTitle;

  /// No description provided for @autostartBody.
  ///
  /// In en, this message translates to:
  /// **'On {maker} phones, also open the app settings and allow Trackie to auto-start and run in the background.'**
  String autostartBody(String maker);

  /// No description provided for @permAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permAllow;

  /// No description provided for @permOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permOpenSettings;

  /// No description provided for @permGranted.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get permGranted;

  /// No description provided for @settingDefaultReminder.
  ///
  /// In en, this message translates to:
  /// **'Default reminder'**
  String get settingDefaultReminder;

  /// No description provided for @settingTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get deleteAllData;

  /// No description provided for @deleteAllDataBody.
  ///
  /// In en, this message translates to:
  /// **'Removes every task, its history and your settings from this phone. This can\'t be undone.'**
  String get deleteAllDataBody;

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteEverything;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan your day. Get reminded on time.'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Choose your language and calendar. You can change them later in Settings.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Make reminders reliable'**
  String get onboardingRemindersTitle;

  /// No description provided for @onboardingRemindersBody.
  ///
  /// In en, this message translates to:
  /// **'Trackie hands each reminder to your phone so it fires even when the app is closed. Allow these so nothing is missed.'**
  String get onboardingRemindersBody;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @semanticsOccurrence.
  ///
  /// In en, this message translates to:
  /// **'{title}, {time}, {status}'**
  String semanticsOccurrence(String title, String time, String status);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['am', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
