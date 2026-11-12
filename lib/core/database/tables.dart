import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New random UUID v4 for a row id. Public because drift copies column
/// defaults into the generated part file.
String newId() => _uuid.v4();

/// Columns every synced table has: UUID id, timestamps and soft delete
/// (section 6). All DateTime columns hold UTC instants.
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newId)();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Single local profile row until accounts arrive (FR-01, FR-20).
class Users extends Table with SyncColumns {
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get calendarType =>
      text().withDefault(const Constant('gregorian'))();
  TextColumn get timezone => text()();

  /// Minutes since local midnight; null = quiet hours off.
  IntColumn get quietStart => integer().nullable()();
  IntColumn get quietEnd => integer().nullable()();
  IntColumn get defaultReminderOffset =>
      integer().withDefault(const Constant(10))();
  TextColumn get theme => text().withDefault(const Constant('system'))();

  /// First-launch setup (language, calendar, permissions) finished.
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();
}

class Categories extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// ARGB colour value.
  IntColumn get color => integer()();
  TextColumn get icon => text()();
}

class Tasks extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();

  /// Local calendar date `YYYY-MM-DD` in [timezone].
  TextColumn get startDate => text()();

  /// Minutes since local midnight; ignored when [isAllDay].
  IntColumn get startMinute => integer().withDefault(const Constant(0))();
  IntColumn get durationMin => integer().withDefault(const Constant(30))();
  TextColumn get priority => text().withDefault(const Constant('normal'))();
  RealColumn get locationLat => real().nullable()();
  RealColumn get locationLng => real().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();

  /// IANA zone the wall-clock time is expressed in, e.g. `Africa/Addis_Ababa`.
  TextColumn get timezone => text()();
}

@DataClassName('RecurrenceRuleRow')
class RecurrenceRules extends Table with SyncColumns {
  TextColumn get taskId => text().unique().references(Tasks, #id)();
  TextColumn get frequency => text()(); // daily / weekly / monthly
  IntColumn get interval => integer().withDefault(const Constant(1))();
  TextColumn get byWeekdays => text().nullable()(); // "1,2,3,4,5"
  TextColumn get endDate => text().nullable()(); // YYYY-MM-DD, inclusive
  IntColumn get count => integer().nullable()();
}

@TableIndex(name: 'idx_occurrences_start', columns: {#scheduledStart})
class Occurrences extends Table with SyncColumns {
  TextColumn get taskId => text().references(Tasks, #id)();

  /// The series date this occurrence belongs to. Unique per task, so window
  /// extension is idempotent and a deleted occurrence (soft-deleted row) is
  /// never regenerated.
  TextColumn get occurrenceDate => text()();
  DateTimeColumn get scheduledStart => dateTime()();
  DateTimeColumn get scheduledEnd => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// True when this occurrence was edited or deleted on its own (FR-05), so
  /// series edits must leave it alone.
  BoolColumn get isException => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {taskId, occurrenceDate},
      ];
}

class Reminders extends Table with SyncColumns {
  TextColumn get taskId => text().references(Tasks, #id)();

  /// 0 = at start, 10 = ten minutes before.
  IntColumn get offsetMin => integer().withDefault(const Constant(0))();
  TextColumn get type => text().withDefault(const Constant('time'))();
  TextColumn get sound => text().nullable()();
  BoolColumn get vibrate => boolean().withDefault(const Constant(true))();
}

/// Maps occurrence × reminder to the OS notification id, so alerts can be
/// cancelled or rescheduled when a task changes. Device-local; never synced.
@TableIndex(name: 'idx_scheduled_fire_at', columns: {#fireAt})
class ScheduledNotifications extends Table {
  IntColumn get osNotificationId => integer()();
  TextColumn get occurrenceId => text().references(Occurrences, #id)();

  /// Null for a snoozed alert, which is not tied to a reminder row.
  TextColumn get reminderId => text().nullable().references(Reminders, #id)();
  DateTimeColumn get fireAt => dateTime()();
  TextColumn get state =>
      text().withDefault(const Constant('scheduled'))(); // scheduled/fired/cancelled

  @override
  Set<Column<Object>> get primaryKey => {osNotificationId};
}

class ActivityLogs extends Table with SyncColumns {
  TextColumn get occurrenceId => text().references(Occurrences, #id)();
  TextColumn get action => text()(); // done/skipped/snoozed/rescheduled/missed
  DateTimeColumn get at => dateTime()();
  TextColumn get note => text().nullable()();
}

class Routines extends Table with SyncColumns {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
}

class RoutineItems extends Table with SyncColumns {
  TextColumn get routineId => text().references(Routines, #id)();
  TextColumn get title => text()();
  IntColumn get startMinute => integer()();
  IntColumn get durationMin => integer()();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class SyncState extends Table {
  TextColumn get syncTableName => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {syncTableName};
}
