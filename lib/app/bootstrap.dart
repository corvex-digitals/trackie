import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/database/app_database.dart';
import '../core/notifications/local_notification_gateway.dart';
import '../core/notifications/notification_actions_handler.dart';
import '../core/notifications/reminder_scheduler.dart';
import '../features/categories/data/category_repository.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/tasks/data/task_repository.dart';
import '../features/tasks/domain/scheduling.dart';

/// The app's long-lived services, built once per isolate (the UI isolate,
/// the notification-action isolate and the background maintenance job each
/// build their own; the database connection is shared between them).
class Services {
  Services._({
    required this.db,
    required this.notifications,
    required this.scheduler,
    required this.tasks,
    required this.categories,
    required this.settings,
    required this.timezone,
  });

  final AppDatabase db;
  final LocalNotificationGateway notifications;
  final ReminderScheduler scheduler;
  final TaskRepository tasks;
  final CategoryRepository categories;
  final SettingsRepository settings;

  /// The device's IANA time zone at startup, e.g. `Africa/Addis_Ababa`.
  final String timezone;

  final _taps = StreamController<String>.broadcast();

  /// Occurrence ids of notifications the user tapped while the app was
  /// running. The UI opens that task.
  Stream<String> get notificationTaps => _taps.stream;

  /// Occurrence id of the notification that launched the app, if any.
  String? launchPayload;

  static Future<Services> create({bool background = false}) async {
    tzdata.initializeTimeZones();
    final zone = await deviceZone();
    tz.setLocalLocation(tz.getLocation(zone));

    final db = AppDatabase.open();
    final user = await (db.select(db.users)..limit(1)).getSingleOrNull();

    late final Services services;
    final gateway = await LocalNotificationGateway.initialize(
      labels: NotificationLabels.forLanguage(user?.language),
      // Button pressed, or notification tapped, while the app is running.
      onResponse: (response) async {
        final handled = await handleNotificationAction(services, response);
        final id = response.payload;
        if (!handled && id != null && id.isNotEmpty) services._taps.add(id);
      },
      onBackgroundResponse: onBackgroundNotificationResponse,
    );
    final scheduler = ReminderScheduler(
      db,
      gateway,
      maxAlarms: Platform.isIOS
          ? SchedulingPolicy.maxScheduledAlarmsIos
          : SchedulingPolicy.maxScheduledAlarmsAndroid,
    );
    final tasks = TaskRepository(db, scheduler);
    final settings = SettingsRepository(
      db,
      onLanguageChanged: (language) async {
        // Re-render pending notifications and their buttons in the new language.
        gateway.labels = NotificationLabels.forLanguage(language);
        await scheduler.rebuildAll(DateTime.now().toUtc());
      },
    );
    services = Services._(
      db: db,
      notifications: gateway,
      scheduler: scheduler,
      tasks: tasks,
      categories: CategoryRepository(db),
      settings: settings,
      timezone: zone,
    );

    if (!background) {
      await tasks.ensureLocalUser(zone);
      services.launchPayload = await gateway.launchPayload();
    }
    return services;
  }

  /// Section 7 maintenance with the current device time zone. Runs after the
  /// first frame on start, on resume and from the background job.
  Future<void> maintain() async {
    final zone = await deviceZone();
    tz.setLocalLocation(tz.getLocation(zone));
    await tasks.runMaintenance(deviceZone: zone);
  }

  /// Erases all data and starts over with a fresh profile (NFR-08).
  Future<void> deleteAllData() async {
    await tasks.deleteAllData();
    await tasks.ensureLocalUser(await deviceZone());
  }

  Future<void> dispose() async {
    await _taps.close();
    await db.close();
  }

  static Future<String> deviceZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.getLocation(info.identifier); // validate
      return info.identifier;
    } catch (_) {
      return 'Africa/Addis_Ababa';
    }
  }
}
