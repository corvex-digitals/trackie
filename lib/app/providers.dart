import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/database/app_database.dart';
import '../core/notifications/local_notification_gateway.dart';
import '../core/utils/local_date.dart';
import '../features/categories/data/category_repository.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/tasks/data/task_repository.dart';
import 'bootstrap.dart';

/// Overridden in `main()` with the instance built during startup.
final servicesProvider = Provider<Services>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) => ref.watch(servicesProvider).tasks);

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => ref.watch(servicesProvider).settings);

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => ref.watch(servicesProvider).categories);

final userProvider = StreamProvider<User?>(
    (ref) => ref.watch(settingsRepositoryProvider).watchUser());

/// The user's IANA time zone. Follows the device: maintenance updates the
/// profile when the device zone changes.
final timezoneProvider = Provider<String>((ref) =>
    ref.watch(userProvider).value?.timezone ??
    ref.watch(servicesProvider).timezone);

final locationProvider =
    Provider<tz.Location>((ref) => tz.getLocation(ref.watch(timezoneProvider)));

final categoriesProvider = StreamProvider<List<Category>>(
    (ref) => ref.watch(categoryRepositoryProvider).watchAll());

/// Occurrences on the local days `from..to` (inclusive), live-updating.
final rangeOccurrencesProvider = StreamProvider.family<List<OccurrenceView>,
    ({LocalDate from, LocalDate to})>((ref, range) {
  return ref
      .watch(taskRepositoryProvider)
      .watchRange(range.from, range.to, ref.watch(locationProvider));
});

/// The occurrences on one calendar day, live-updating.
final dayOccurrencesProvider =
    Provider.family<AsyncValue<List<OccurrenceView>>, LocalDate>((ref, date) =>
        ref.watch(rangeOccurrencesProvider((from: date, to: date))));

/// Notification permission, exact alarms and battery status (NFR-01).
/// Invalidate it to re-check, e.g. after returning from system settings.
final reminderHealthProvider = FutureProvider<ReminderHealth>(
    (ref) => ref.watch(servicesProvider).notifications.checkHealth());
