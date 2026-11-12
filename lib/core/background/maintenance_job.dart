import 'dart:io' show Platform;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/bootstrap.dart';
import '../../features/tasks/domain/scheduling.dart';

const _jobId = 4201;

/// Runs section 7 maintenance in the background on Android: at local
/// midnight and then every [SchedulingPolicy.maintenanceInterval], surviving
/// reboots. Keeps the 14-day window rolling, marks missed occurrences and
/// follows time-zone changes even when the app is never opened.
///
/// Uses an inexact alarm, so the OS batches it with other wake-ups; there is
/// no long-running background service (NFR-05).
Future<void> scheduleMaintenanceJob(tz.Location location) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await AndroidAlarmManager.initialize();
    final now = tz.TZDateTime.now(location);
    final midnight = tz.TZDateTime(location, now.year, now.month, now.day + 1);
    await AndroidAlarmManager.periodic(
      SchedulingPolicy.maintenanceInterval,
      _jobId, // same id: replaces the previous registration
      runMaintenanceJob,
      startAt: midnight,
      allowWhileIdle: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  } catch (e) {
    debugPrint('Could not schedule maintenance job: $e');
  }
}

@pragma('vm:entry-point')
Future<void> runMaintenanceJob() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final services = await Services.create(background: true);
  try {
    await services.maintain();
  } finally {
    await services.dispose();
  }
}
