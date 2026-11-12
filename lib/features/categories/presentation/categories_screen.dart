import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/category_style.dart';

/// Create, edit and delete categories (FR-19). Opened from Settings.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.categoriesTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.newCategory,
        onPressed: () => CategoryEditor.show(context),
        child: const Icon(Icons.add),
      ),
      body: switch (categories) {
        AsyncData(:final value) when value.isEmpty => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.noCategories, textAlign: TextAlign.center),
            ),
          ),
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final c in value)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(c.color),
                    foregroundColor: Colors.white,
                    child: Icon(CategoryStyle.icon(c.icon)),
                  ),
                  title: Text(c.name),
                  onTap: () => CategoryEditor.show(context, existing: c),
                  trailing: IconButton(
                    tooltip: l.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, c),
                  ),
                ),
            ],
          ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category category) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteCategoryTitle(category.name)),
        content: Text(l.deleteCategoryBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) await ref.read(categoryRepositoryProvider).delete(category.id);
  }
}

/// Bottom sheet to create or edit a category: name, colour and icon.
class CategoryEditor extends ConsumerStatefulWidget {
  const CategoryEditor({super.key, this.existing});
  final Category? existing;

  static Future<void> show(BuildContext context, {Category? existing}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: CategoryEditor(existing: existing),
        ),
      );

  @override
  ConsumerState<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<CategoryEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late int _color = widget.existing?.color ?? CategoryStyle.colors.first;
  late String _icon = widget.existing?.icon ?? 'other';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(categoryRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repo.create(name: _name.text, color: _color, icon: _icon);
    } else {
      await repo.update(existing.id, name: _name.text, color: _color, icon: _icon);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing == null ? l.newCategory : l.editCategory,
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: widget.existing == null,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.fieldName),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.nameRequired : null,
              ),
              const SizedBox(height: 8),
              Text(l.fieldColor, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in CategoryStyle.colors)
                    Semantics(
                      selected: c == _color,
                      button: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _color = c),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(c),
                          child: c == _color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l.fieldIcon, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final entry in CategoryStyle.icons.entries)
                    IconButton.filledTonal(
                      isSelected: entry.key == _icon,
                      tooltip: entry.key,
                      onPressed: () => setState(() => _icon = entry.key),
                      icon: Icon(entry.value),
                      selectedIcon: Icon(entry.value, color: Color(_color)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l.cancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l.save)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
