/// The thin boundary to the OS notification system, so the scheduling logic
/// can be unit-tested with a fake.
abstract interface class NotificationGateway {
  Future<void> schedule({
    required int id,
    required DateTime fireAtUtc,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);

  /// Cancels every pending and shown notification of the app.
  Future<void> cancelAll();
}

/// Action ids on a reminder notification (FR-09).
///
/// Android shows at most three action buttons, so the notification offers
/// Done, Snooze 10 min and Snooze 30 min; tapping the notification opens the
/// app on that task, where 5 minutes is also offered.
abstract final class NotificationActions {
  static const done = 'done';
  static const snooze10 = 'snooze_10';
  static const snooze30 = 'snooze_30';

  /// The snooze length for an action id, or null if it is not a snooze.
  static Duration? snoozeDuration(String? actionId) => switch (actionId) {
        snooze10 => const Duration(minutes: 10),
        snooze30 => const Duration(minutes: 30),
        _ => null,
      };
}
