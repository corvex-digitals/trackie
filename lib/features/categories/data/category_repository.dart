import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_style.dart';

/// Categories with name, colour and icon (FR-19).
class CategoryRepository {
  CategoryRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<Category>> watchAll() => (_db.select(_db.categories)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();

  Future<String> create({
    required String name,
    required int color,
    required String icon,
  }) async {
    final user = await (_db.select(_db.users)..limit(1)).getSingle();
    final row = await _db.into(_db.categories).insertReturning(
          CategoriesCompanion.insert(
            userId: user.id,
            name: _validName(name),
            color: color,
            icon: icon,
          ),
        );
    return row.id;
  }

  Future<void> update(
    String id, {
    required String name,
    required int color,
    required String icon,
  }) =>
      (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(_validName(name)),
          color: Value(color),
          icon: Value(icon),
          updatedAt: Value(_clock()),
        ),
      );

  /// Soft-deletes the category; its tasks become uncategorised.
  Future<void> delete(String id) => _db.transaction(() async {
        final now = _clock();
        await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
            .write(CategoriesCompanion(
                deletedAt: Value(now), updatedAt: Value(now)));
        await (_db.update(_db.tasks)..where((t) => t.categoryId.equals(id)))
            .write(TasksCompanion(
                categoryId: const Value(null), updatedAt: Value(now)));
      });

  /// Creates the starter categories once, named in [language]. Does nothing
  /// if the user has ever had categories.
  Future<void> seedDefaults(String language) => _db.transaction(() async {
        final any = await (_db.select(_db.categories)..limit(1)).getSingleOrNull();
        if (any != null) return;
        for (final c in DefaultCategory.all) {
          await create(name: c.name(language), color: c.color, icon: c.icon);
        }
      });

  static String _validName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError.value(name, 'name', 'must be 1–60 characters');
    }
    return trimmed;
  }
}
