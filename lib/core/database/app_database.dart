import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  Categories,
  Tasks,
  RecurrenceRules,
  Occurrences,
  Reminders,
  ScheduledNotifications,
  ActivityLogs,
  Routines,
  RoutineItems,
  SyncState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The on-device database. `shareAcrossIsolates` lets the notification
  /// action handler (which runs in a background isolate) use the same
  /// connection safely.
  factory AppDatabase.open() => AppDatabase(
        driftDatabase(
          name: 'trackie',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
