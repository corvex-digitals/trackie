import 'package:trackie/core/notifications/notification_gateway.dart';

class ScheduledAlert {
  ScheduledAlert(this.id, this.fireAtUtc, this.title, this.body, this.payload);
  final int id;
  final DateTime fireAtUtc;
  final String title;
  final String body;
  final String payload;
}

/// Records what would be handed to the OS.
class FakeNotificationGateway implements NotificationGateway {
  final active = <int, ScheduledAlert>{};
  int scheduleCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> schedule({
    required int id,
    required DateTime fireAtUtc,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduleCalls++;
    if (active.containsKey(id)) throw StateError('OS id $id reused while active');
    active[id] = ScheduledAlert(id, fireAtUtc, title, body, payload);
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
    active.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    active.clear();
  }

  List<ScheduledAlert> forOccurrence(String occurrenceId) =>
      active.values.where((a) => a.payload == occurrenceId).toList();
}
