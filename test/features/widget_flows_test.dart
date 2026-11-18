import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:trackie/app/providers.dart';
import 'package:trackie/core/database/app_database.dart';
import 'package:trackie/core/notifications/local_notification_gateway.dart';
import 'package:trackie/core/notifications/reminder_scheduler.dart';
import 'package:trackie/core/utils/ethiopian_calendar.dart';
import 'package:trackie/core/utils/local_date.dart';
import 'package:trackie/features/calendar/presentation/calendar_screen.dart';
import 'package:trackie/features/categories/data/category_repository.dart';
import 'package:trackie/features/onboarding/presentation/onboarding_screen.dart';
import 'package:trackie/features/settings/data/settings_repository.dart';
import 'package:trackie/features/settings/presentation/settings_screen.dart';
import 'package:trackie/features/tasks/data/task_repository.dart';
import 'package:trackie/features/tasks/domain/task_draft.dart';
import 'package:trackie/features/tasks/presentation/task_editor_screen.dart';
import 'package:trackie/features/today/presentation/day_timeline.dart';
import 'package:trackie/features/today/presentation/today_screen.dart';
import 'package:trackie/l10n/app_localizations.dart';

import '../support/fake_notification_gateway.dart';

const zone = 'Africa/Addis_Ababa';

/// Notes on drift in widget tests: data is written before the screen
/// subscribes, and read back after it is unmounted. A drift stream query
/// running in the tester's fake-async zone would otherwise hold the database
/// lock while `runAsync` waits for it.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late TaskRepository repo;
  late CategoryRepository categories;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    repo = TaskRepository(db, ReminderScheduler(db, FakeNotificationGateway()));
    categories = CategoryRepository(db);
    await repo.ensureLocalUser(zone);
    await (db.update(db.users))
        .write(const UsersCompanion(onboardingCompleted: Value(true)));
  });

  tearDown(() => db.close());

  Widget host(Widget child) => ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repo),
          categoryRepositoryProvider.overrideWithValue(categories),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
          timezoneProvider.overrideWithValue(zone),
          reminderHealthProvider.overrideWith((ref) async => const ReminderHealth(
                notificationsAllowed: true,
                exactAlarmsAllowed: true,
                batteryUnrestricted: true,
                manufacturer: 'google',
              )),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  /// Unmounts the UI (stops stream queries and timers) before reading the DB.
  Future<T> readAfter<T>(WidgetTester tester, Future<T> Function() query) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    return (await tester.runAsync(query)) as T;
  }

  LocalDate today() => LocalDate.fromDateTime(tz.TZDateTime.now(tz.getLocation(zone)));

  testWidgets('task editor requires a title and saves nothing without one',
      (tester) async {
    await tester.pumpWidget(host(const TaskEditorScreen()));
    await settle(tester);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter a title'), findsOneWidget);
    expect(await readAfter(tester, () => db.select(db.tasks).get()), isEmpty);
  });

  testWidgets('task editor saves title, default reminder and category',
      (tester) async {
    await tester.runAsync(() => categories.seedDefaults('en'));
    await tester.pumpWidget(host(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => TaskEditorScreen.open(context),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Read 20 pages');
    await tester.tap(find.text('No category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('open'), findsOneWidget); // editor closed

    final task = await readAfter(tester, () => db.select(db.tasks).getSingle());
    expect(task.title, 'Read 20 pages');
    final study = (await tester.runAsync(() => categories.watchAll().first))!
        .firstWhere((c) => c.name == 'Study');
    expect(task.categoryId, study.id);
    final reminders = await tester.runAsync(() => db.select(db.reminders).get());
    expect(reminders!.single.offsetMin, 10);
  });

  testWidgets('Today shows the empty state', (tester) async {
    await tester.pumpWidget(host(const TodayScreen()));
    await settle(tester);
    expect(find.text('Nothing planned today'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop the minute ticker
  });

  testWidgets('Today shows only today\'s tasks', (tester) async {
    await tester.runAsync(() async {
      await repo.createTask(TaskDraft(
          title: 'Standup', startDate: today(), startMinute: 9 * 60, timezone: zone));
      await repo.createTask(TaskDraft(
          title: 'Tomorrow only',
          startDate: today().addDays(1),
          startMinute: 9 * 60,
          timezone: zone));
    });
    await tester.pumpWidget(host(const TodayScreen()));
    await settle(tester);

    // Look inside the timeline only: before 9:00 the "next up" card also
    // shows Standup, which would make this test depend on the time of day.
    Finder inTimeline(String text) => find.descendant(
        of: find.byType(DayTimeline),
        matching: find.textContaining(text, findRichText: true));
    expect(inTimeline('Standup'), findsOneWidget);
    expect(find.textContaining('Tomorrow only', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping a task opens its actions; Done marks it done',
      (tester) async {
    await tester.runAsync(() => repo.createTask(TaskDraft(
        title: 'Standup', startDate: today(), startMinute: 9 * 60, timezone: zone)));
    await tester.pumpWidget(host(const TodayScreen()));
    await settle(tester);

    final card = find.textContaining('Standup', findRichText: true).last;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Snooze'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Done'));
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('· Done', findRichText: true), findsOneWidget);
    expect(find.text('Marked done'), findsOneWidget);

    final occ = await readAfter(tester, () => db.select(db.occurrences).getSingle());
    expect(occ.status, 'done');
  });

  testWidgets('month view follows the Ethiopian calendar', (tester) async {
    await tester.runAsync(() => db.update(db.users)
        .write(const UsersCompanion(calendarType: Value('ethiopian'))));
    await tester.pumpWidget(host(const CalendarScreen()));
    await settle(tester);

    final e = EthiopianDate.fromGregorian(today());
    final title = '${EthiopianDate.monthNamesEn[e.month - 1]} ${e.year}';
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await settle(tester);
    final nextMonth = e.month == 13 ? 1 : e.month + 1;
    final nextYear = e.month == 13 ? e.year + 1 : e.year;
    expect(find.text('${EthiopianDate.monthNamesEn[nextMonth - 1]} $nextYear'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('week view lists each day with its tasks', (tester) async {
    await tester.runAsync(() => repo.createTask(TaskDraft(
        title: 'Standup', startDate: today(), startMinute: 9 * 60, timezone: zone)));
    await tester.pumpWidget(host(const CalendarScreen()));
    await settle(tester);
    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('No tasks'), findsWidgets); // the other days (built lazily)
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('onboarding finishes and seeds starter categories', (tester) async {
    await tester.runAsync(() => db.update(db.users)
        .write(const UsersCompanion(onboardingCompleted: Value(false))));
    await tester.pumpWidget(host(const OnboardingScreen()));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Ethiopian'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Ethiopian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ethiopian'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Make reminders reliable'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget); // notifications (fake)

    await tester.tap(find.text('Get started'));
    await settle(tester);

    final user = await readAfter(tester, () => db.select(db.users).getSingle());
    expect(user.onboardingCompleted, isTrue);
    expect(user.calendarType, 'ethiopian');
    expect(await tester.runAsync(() => categories.watchAll().first), hasLength(4));
  });

  testWidgets('settings change the theme and default reminder', (tester) async {
    await tester.pumpWidget(host(const SettingsScreen()));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Dark'), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Default reminder'), -100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Default reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min before'));
    await settle(tester);

    final user = await readAfter(tester, () => db.select(db.users).getSingle());
    expect(user.theme, 'dark');
    expect(user.defaultReminderOffset, 30);
  });
}
