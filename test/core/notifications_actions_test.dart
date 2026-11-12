import 'package:flutter_test/flutter_test.dart';
import 'package:trackie/core/notifications/local_notification_gateway.dart';
import 'package:trackie/core/notifications/notification_gateway.dart';

void main() {
  test('snooze durations per notification button', () {
    expect(NotificationActions.snoozeDuration(NotificationActions.snooze10),
        const Duration(minutes: 10));
    expect(NotificationActions.snoozeDuration(NotificationActions.snooze30),
        const Duration(minutes: 30));
    expect(NotificationActions.snoozeDuration(NotificationActions.done), isNull);
    expect(NotificationActions.snoozeDuration(null), isNull);
  });

  test('notification labels follow the language', () {
    expect(NotificationLabels.forLanguage('am').done, 'ተከናውኗል');
    expect(NotificationLabels.forLanguage('en').snooze30, 'Snooze 30 min');
    expect(NotificationLabels.forLanguage(null).done, 'Done');
  });
}
