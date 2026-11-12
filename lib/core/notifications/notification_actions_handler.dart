import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/bootstrap.dart';
import '../../features/tasks/domain/scheduling.dart';
import 'notification_gateway.dart';

/// Handles Done / Snooze tapped on a notification while the app is not in
/// the foreground (FR-09). Runs in a separate background isolate, so it
/// builds its own services.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final services = await Services.create(background: true);
  try {
    await handleNotificationAction(services, response);
  } finally {
    await services.dispose();
  }
}

/// Applies a notification button. Returns false when the response was a tap
/// on the notification itself (the app then opens that task).
Future<bool> handleNotificationAction(
  Services services,
  NotificationResponse response,
) async {
  final occurrenceId = response.payload;
  if (occurrenceId == null || occurrenceId.isEmpty) return true;

  final actionId = response.actionId;
  if (actionId == NotificationActions.done) {
    await services.tasks.setStatus(occurrenceId, OccurrenceStatus.done);
    return true;
  }
  final snooze = NotificationActions.snoozeDuration(actionId);
  if (snooze != null) {
    await services.scheduler.snooze(occurrenceId, snooze, DateTime.now().toUtc());
    return true;
  }
  return false;
}
