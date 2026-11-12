import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Profile settings stored on the local user row (FR-20).
class SettingsRepository {
  SettingsRepository(this._db, {this.onLanguageChanged});

  final AppDatabase _db;

  /// Lets the notification layer re-render pending alerts in the new
  /// language.
  final Future<void> Function(String language)? onLanguageChanged;

  Stream<User?> watchUser() =>
      (_db.select(_db.users)..limit(1)).watchSingleOrNull();

  Future<void> setLanguage(String code) async {
    await _write(UsersCompanion(language: Value(code)));
    await onLanguageChanged?.call(code);
  }

  Future<void> setCalendarType(String type) =>
      _write(UsersCompanion(calendarType: Value(type)));

  /// `system`, `light` or `dark`.
  Future<void> setTheme(String theme) =>
      _write(UsersCompanion(theme: Value(theme)));

  /// Minutes before start used for new tasks' reminder.
  Future<void> setDefaultReminderOffset(int minutes) =>
      _write(UsersCompanion(defaultReminderOffset: Value(minutes)));

  Future<void> completeOnboarding() =>
      _write(const UsersCompanion(onboardingCompleted: Value(true)));

  Future<void> _write(UsersCompanion values) => _db.update(_db.users).write(
      values.copyWith(updatedAt: Value(DateTime.now().toUtc())));
}
