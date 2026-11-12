// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'Trackie';

  @override
  String get tabToday => 'ዛሬ';

  @override
  String get tabCalendar => 'የቀን መቁጠሪያ';

  @override
  String get tabInsights => 'ግንዛቤዎች';

  @override
  String get tabSettings => 'ቅንብሮች';

  @override
  String get newTask => 'አዲስ ተግባር';

  @override
  String get editTask => 'ተግባር አስተካክል';

  @override
  String get fieldTitle => 'ርዕስ';

  @override
  String get fieldDate => 'ቀን';

  @override
  String get fieldTime => 'ሰዓት';

  @override
  String get fieldDuration => 'የቆይታ ጊዜ';

  @override
  String get fieldNotes => 'ማስታወሻ';

  @override
  String get fieldPriority => 'ቅድሚያ';

  @override
  String get fieldRepeat => 'ድግግሞሽ';

  @override
  String get fieldReminders => 'ማሳሰቢያዎች';

  @override
  String get priorityLow => 'ዝቅተኛ';

  @override
  String get priorityNormal => 'መደበኛ';

  @override
  String get priorityHigh => 'ከፍተኛ';

  @override
  String get repeatNone => 'አይደገምም';

  @override
  String get repeatDaily => 'በየቀኑ';

  @override
  String get repeatWeekdays => 'የሥራ ቀናት (ሰኞ–ዓርብ)';

  @override
  String get repeatWeekly => 'በየሳምንቱ';

  @override
  String get repeatMonthly => 'በየወሩ';

  @override
  String get reminderAtStart => 'ሲጀምር';

  @override
  String reminderBefore(int minutes) {
    return 'ከ$minutes ደቂቃ በፊት';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes ደቂቃ';
  }

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ተው';

  @override
  String get delete => 'ሰርዝ';

  @override
  String get undo => 'መልስ';

  @override
  String get titleRequired => 'ርዕስ ያስገቡ';

  @override
  String get applyToWhich => 'ለየትኞቹ ይተገበር?';

  @override
  String get onlyThisOne => 'ይህን ብቻ';

  @override
  String get wholeSeries => 'ሁሉንም ተደጋጋሚዎች';

  @override
  String get actionDone => 'ተከናውኗል';

  @override
  String get actionSkip => 'ዝለል';

  @override
  String get statusDone => 'ተከናውኗል';

  @override
  String get statusSkipped => 'ተዘሏል';

  @override
  String get statusMissed => 'ያመለጠ';

  @override
  String get markedDone => 'ተከናውኗል ተብሎ ተመዝግቧል';

  @override
  String get markedSkipped => 'ተዘሏል';

  @override
  String get emptyTodayTitle => 'ዛሬ የታቀደ ነገር የለም';

  @override
  String get emptyTodayBody => 'የመጀመሪያ ተግባርዎን ለመጨመር + ይንኩ።';

  @override
  String get nextUp => 'ቀጣይ';

  @override
  String get comingSoon => 'በሚቀጥለው ስሪት ይመጣል';

  @override
  String get settingLanguage => 'ቋንቋ';

  @override
  String get settingCalendar => 'የቀን አቆጣጠር';

  @override
  String get calendarGregorian => 'ግሪጎሪያን';

  @override
  String get calendarEthiopian => 'ኢትዮጵያዊ';

  @override
  String get enableNotifications => 'ማሳሰቢያዎችን ፍቀድ';

  @override
  String get enableNotificationsBody =>
      'Trackie በእያንዳንዱ ተግባር ትክክለኛ ሰዓት እንዲያሳውቅዎ ፈቃድ ያስፈልገዋል።';

  @override
  String get statusPending => 'የታቀደ';

  @override
  String get actionSnooze => 'አራዝም';

  @override
  String snoozeMinutes(int minutes) {
    return '$minutes ደቂቃ';
  }

  @override
  String snoozedFor(int minutes) {
    return 'ማሳሰቢያው ለ$minutes ደቂቃ ተራዝሟል';
  }

  @override
  String get actionReschedule => 'ጊዜ ቀይር';

  @override
  String get actionEdit => 'አስተካክል';

  @override
  String get actionReset => 'እንዳልተከናወነ ምልክት አድርግ';

  @override
  String rescheduled(String time) {
    return 'ወደ $time ተዛውሯል';
  }

  @override
  String get projectedNote =>
      'ይህ የተደጋጋሚው የወደፊት ክፍል ነው። ለመቀየር ሙሉውን ተደጋጋሚ ያስተካክሉ።';

  @override
  String get editSeries => 'ተደጋጋሚውን አስተካክል';

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get fieldCategory => 'ምድብ';

  @override
  String get categoryNone => 'ምድብ የለም';

  @override
  String get viewWeek => 'ሳምንት';

  @override
  String get viewMonth => 'ወር';

  @override
  String get previous => 'ቀዳሚ';

  @override
  String get next => 'ቀጣይ';

  @override
  String get goToToday => 'ዛሬ';

  @override
  String get noTasks => 'ምንም ተግባር የለም';

  @override
  String moreCount(int count) {
    return '+$count ተጨማሪ';
  }

  @override
  String get categoriesTitle => 'ምድቦች';

  @override
  String get newCategory => 'አዲስ ምድብ';

  @override
  String get editCategory => 'ምድብ አስተካክል';

  @override
  String get fieldName => 'ስም';

  @override
  String get fieldColor => 'ቀለም';

  @override
  String get fieldIcon => 'ምልክት';

  @override
  String get nameRequired => 'ስም ያስገቡ';

  @override
  String get noCategories => 'እስካሁን ምድብ የለም። ለመጨመር + ይንኩ።';

  @override
  String deleteCategoryTitle(String name) {
    return '\"$name\" ይሰረዝ?';
  }

  @override
  String get deleteCategoryBody => 'ተግባሮቹ ያለ ምድብ ይቀመጣሉ።';

  @override
  String get sectionReminders => 'ማሳሰቢያዎች';

  @override
  String get sectionGeneral => 'አጠቃላይ';

  @override
  String get sectionData => 'የእርስዎ መረጃ';

  @override
  String get remindersReady => 'ማሳሰቢያዎች በሰዓቱ እንዲደርሱ ተዘጋጅተዋል።';

  @override
  String get remindersAttention => 'አንዳንድ ቅንብሮች ማሳሰቢያዎችዎን ሊያዘገዩ ወይም ሊያግዱ ይችላሉ።';

  @override
  String get permNotificationsTitle => 'ማሳወቂያዎች';

  @override
  String get permNotificationsBody => 'ማሳሰቢያዎችን ለማሳየት ያስፈልጋል።';

  @override
  String get permExactTitle => 'ማንቂያዎች እና ማሳሰቢያዎች';

  @override
  String get permExactBody => 'ማሳሰቢያዎች በትክክለኛው ደቂቃ እንዲደርሱ ያደርጋል።';

  @override
  String get permBatteryTitle => 'ባትሪ፦ ያልተገደበ';

  @override
  String get permBatteryBody =>
      'አንዳንድ ስልኮች ባትሪ ለመቆጠብ ማሳሰቢያዎችን ያቆማሉ። በዝርዝሩ ውስጥ Trackieን \"ያልተገደበ\" ያድርጉት።';

  @override
  String get autostartTitle => 'በራስ መጀመር';

  @override
  String autostartBody(String maker) {
    return 'በ$maker ስልኮች ላይ፣ የመተግበሪያ ቅንብሮችን ከፍተው Trackie በራሱ እንዲጀምር እና ከበስተጀርባ እንዲሠራ ይፍቀዱ።';
  }

  @override
  String get permAllow => 'ፍቀድ';

  @override
  String get permOpenSettings => 'ቅንብሮችን ክፈት';

  @override
  String get permGranted => 'ተፈቅዷል';

  @override
  String get settingDefaultReminder => 'ነባሪ ማሳሰቢያ';

  @override
  String get settingTheme => 'ገጽታ';

  @override
  String get themeSystem => 'የስልኩ';

  @override
  String get themeLight => 'ብሩህ';

  @override
  String get themeDark => 'ጨለማ';

  @override
  String get deleteAllData => 'ሁሉንም መረጃ ሰርዝ';

  @override
  String get deleteAllDataBody =>
      'ሁሉንም ተግባሮች፣ ታሪካቸውን እና ቅንብሮችዎን ከዚህ ስልክ ያስወግዳል። ይህ ሊመለስ አይችልም።';

  @override
  String get deleteEverything => 'ሁሉንም ሰርዝ';

  @override
  String get onboardingWelcomeTitle => 'ቀንዎን ያቅዱ። በሰዓቱ ይታወሱ።';

  @override
  String get onboardingWelcomeBody =>
      'ቋንቋዎን እና የቀን አቆጣጠርዎን ይምረጡ። በኋላ በቅንብሮች ውስጥ መቀየር ይችላሉ።';

  @override
  String get onboardingRemindersTitle => 'ማሳሰቢያዎችን አስተማማኝ ያድርጉ';

  @override
  String get onboardingRemindersBody =>
      'Trackie መተግበሪያው ቢዘጋም እንዲደርስ እያንዳንዱን ማሳሰቢያ ለስልክዎ ይሰጣል። ምንም እንዳያመልጥ እነዚህን ይፍቀዱ።';

  @override
  String get continueButton => 'ቀጥል';

  @override
  String get getStarted => 'ጀምር';

  @override
  String get back => 'ተመለስ';

  @override
  String semanticsOccurrence(String title, String time, String status) {
    return '$title፣ $time፣ $status';
  }
}
