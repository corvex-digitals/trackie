import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:trackie/core/database/app_database.dart';
import 'package:trackie/core/notifications/reminder_scheduler.dart';
import 'package:trackie/core/utils/local_date.dart';
import 'package:trackie/features/categories/data/category_repository.dart';
import 'package:trackie/features/tasks/data/task_repository.dart';
import 'package:trackie/features/tasks/domain/task_draft.dart';

import '../../support/fake_notification_gateway.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  late AppDatabase db;
  late CategoryRepository categories;
  late TaskRepository tasks;

  setUp(() async {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    categories = CategoryRepository(db);
    tasks = TaskRepository(db, ReminderScheduler(db, FakeNotificationGateway()));
    await tasks.ensureLocalUser('Africa/Addis_Ababa');
  });

  tearDown(() => db.close());

  test('create, rename and list alphabetically', () async {
    final id = await categories.create(name: ' Work ', color: 0xFF1E88E5, icon: 'work');
    await categories.create(name: 'Church', color: 0xFF8E24AA, icon: 'faith');
    await categories.update(id, name: 'Office', color: 0xFF000000, icon: 'work');
    final all = await categories.watchAll().first;
    expect(all.map((c) => c.name), ['Church', 'Office']);
    expect(all.last.color, 0xFF000000);
  });

  test('rejects empty names', () {
    expect(() => categories.create(name: '  ', color: 0, icon: 'x'), throwsArgumentError);
  });

  test('deleting a category un-assigns its tasks', () async {
    final id = await categories.create(name: 'Gym', color: 0, icon: 'fitness');
    final taskId = await tasks.createTask(TaskDraft(
      title: 'Leg day',
      startDate: LocalDate(2026, 11, 12),
      startMinute: 18 * 60,
      timezone: 'Africa/Addis_Ababa',
      categoryId: id,
    ));
    await categories.delete(id);
    expect(await categories.watchAll().first, isEmpty);
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
    expect(task.categoryId, isNull);
  });

  test('defaults are seeded once, in the chosen language', () async {
    await categories.seedDefaults('am');
    await categories.seedDefaults('am');
    final all = await categories.watchAll().first;
    expect(all, hasLength(4));
    expect(all.map((c) => c.name), contains('ጤና'));
  });

  test('defaults are not re-created after the user deleted them', () async {
    await categories.seedDefaults('en');
    for (final c in await categories.watchAll().first) {
      await categories.delete(c.id);
    }
    await categories.seedDefaults('en');
    expect(await categories.watchAll().first, isEmpty);
  });
}
