import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../platform/system_settings.dart';
import 'notification_gateway.dart';

/// Labels shown on notification buttons, in the user's language.
class NotificationLabels {
  const NotificationLabels({
    required this.done,
    required this.snooze10,
    required this.snooze30,
    required this.channelName,
    required this.channelDescription,
  });

  final String done;
  final String snooze10;
  final String snooze30;
  final String channelName;
  final String channelDescription;

  static NotificationLabels forLanguage(String? code) => code == 'am'
      ? const NotificationLabels(
          done: 'ተከናውኗል',
          snooze10: '10 ደቂቃ አራዝም',
          snooze30: '30 ደቂቃ አራዝም',
          channelName: 'ማሳሰቢያዎች',
          channelDescription: 'ለታቀዱ ተግባሮችዎ ማሳሰቢያዎች',
        )
      : const NotificationLabels(
          done: 'Done',
          snooze10: 'Snooze 10 min',
          snooze30: 'Snooze 30 min',
          channelName: 'Reminders',
          channelDescription: 'Alerts for your scheduled tasks',
        );
}

/// What stands between the app and on-time reminders (NFR-01).
class ReminderHealth {
  const ReminderHealth({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
    required this.manufacturer,
  });

  final bool notificationsAllowed;

  /// Android 12+: alarms fire to the minute. Always true on iOS.
  final bool exactAlarmsAllowed;

  /// Android: the app is exempt from battery optimisation. True on iOS.
  final bool batteryUnrestricted;
  final String manufacturer;

  bool get needsAutostartTip => aggressiveBatteryMakers.contains(manufacturer);

  bool get allGood =>
      notificationsAllowed && exactAlarmsAllowed && batteryUnrestricted;
}

/// [NotificationGateway] backed by flutter_local_notifications.
///
/// Alarms are handed to the OS (AlarmManager on Android, UNUserNotification
/// on iOS), so they fire when the app is killed. The plugin's boot receiver
/// re-registers them after a reboot (FR-08); the app additionally runs
/// [ReminderScheduler.resync] on start, on resume and from a background job.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway(this._plugin, this.labels);

  final FlutterLocalNotificationsPlugin _plugin;
  final _system = const SystemSettings();

  /// Updated when the user changes language; applies to alerts scheduled
  /// from then on (the scheduler re-registers all alerts on a change).
  NotificationLabels labels;

  static const _channelId = 'reminders';
  static const _iosCategory = 'reminder';

  /// Monochrome status-bar icon (`res/drawable/ic_stat_notification.xml`),
  /// protected from resource shrinking by `res/raw/keep.xml`.
  static const _smallIcon = 'ic_stat_notification';

  static Future<LocalNotificationGateway> initialize({
    required NotificationLabels labels,
    required DidReceiveNotificationResponseCallback onResponse,
    required DidReceiveBackgroundNotificationResponseCallback onBackgroundResponse,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          // Permissions are asked during onboarding, not at startup.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _iosCategory,
              actions: [
                DarwinNotificationAction.plain(NotificationActions.done, labels.done),
                DarwinNotificationAction.plain(
                    NotificationActions.snooze10, labels.snooze10),
                DarwinNotificationAction.plain(
                    NotificationActions.snooze30, labels.snooze30),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
    return LocalNotificationGateway(plugin, labels);
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// The payload (occurrence id) if the app was launched by tapping a
  /// notification.
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final response = details.notificationResponse;
    // A button press is handled by the action handler, not by opening a task.
    if (response?.actionId != null) return null;
    return response?.payload;
  }

  Future<ReminderHealth> checkHealth() async {
    final android = _android;
    bool notifications;
    var exact = true;
    if (android != null) {
      notifications = await android.areNotificationsEnabled() ?? false;
      exact = await android.canScheduleExactNotifications() ?? false;
    } else {
      final options = await _ios?.checkPermissions();
      notifications = options?.isEnabled ?? false;
    }
    return ReminderHealth(
      notificationsAllowed: notifications,
      exactAlarmsAllowed: exact,
      batteryUnrestricted: await _system.isIgnoringBatteryOptimizations(),
      manufacturer: await _system.manufacturer(),
    );
  }

  /// Shows the notification permission prompt (Android 13+, iOS). Returns
  /// whether notifications are allowed.
  Future<bool> requestNotificationPermission() async {
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    return await _ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  /// Android 12+: opens the "Alarms & reminders" permission screen.
  Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  Future<void> openBatterySettings() => _system.openBatteryOptimizationSettings();

  Future<void> openAppSettings() => _system.openAppSettings();

  @override
  Future<void> schedule({
    required int id,
    required DateTime fireAtUtc,
    required String title,
    required String body,
    required String payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        labels.channelName,
        channelDescription: labels.channelDescription,
        icon: _smallIcon,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: [
          AndroidNotificationAction(NotificationActions.done, labels.done),
          AndroidNotificationAction(NotificationActions.snooze10, labels.snooze10),
          AndroidNotificationAction(NotificationActions.snooze30, labels.snooze30),
        ],
      ),
      iOS: const DarwinNotificationDetails(categoryIdentifier: _iosCategory),
    );
    final when = tz.TZDateTime.from(fireAtUtc, tz.UTC);

    Future<void> scheduleWith(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: mode,
          title: title,
          body: body,
          payload: payload,
        );

    try {
      await scheduleWith(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      // Exact-alarm permission revoked or not granted (Android 12+): still
      // deliver the reminder, possibly a few minutes late, rather than drop it.
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      debugPrint('Exact alarms not permitted; falling back to inexact.');
      await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
