import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/providers.dart';
import '../../../core/utils/date_display.dart';
import '../../../core/utils/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../categories/domain/category_style.dart';
import '../data/task_repository.dart';
import '../domain/recurrence.dart';
import '../domain/scheduling.dart';
import '../domain/task_draft.dart';

enum _Repeat { none, daily, weekdays, weekly, monthly, custom }

enum _Scope { single, series }

/// Full-screen task editor (FR-03, FR-04, FR-05, FR-07, FR-19). Opened
/// from the + button (new task) or from an occurrence (edit).
class TaskEditorScreen extends ConsumerStatefulWidget {
  const TaskEditorScreen({super.key, this.existing, this.initialDate});

  final OccurrenceView? existing;

  /// Date for a new task (e.g. the day open in the calendar); default today.
  final LocalDate? initialDate;

  static Future<void> open(BuildContext context,
          {OccurrenceView? existing, LocalDate? initialDate}) =>
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            TaskEditorScreen(existing: existing, initialDate: initialDate),
      ));

  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen> {
  static const _durations = [15, 30, 45, 60, 90, 120, 180];

  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();

  late LocalDate _date;
  late int _startMinute;
  int _duration = 30;
  Priority _priority = Priority.normal;
  String? _categoryId;
  _Repeat _repeat = _Repeat.none;
  RecurrenceRule? _originalRule;
  Set<int> _reminders = {10};
  bool _loading = false;
  bool _saving = false;

  tz.Location get _location => ref.read(locationProvider);
  bool get _isEdit => widget.existing != null;
  bool get _wasRecurring => _originalRule != null;

  /// A projected (future, not yet stored) occurrence can only be changed
  /// through its series.
  bool get _canEditSingle =>
      _wasRecurring && !(widget.existing?.isProjected ?? false);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      final now = tz.TZDateTime.now(_location);
      _date = widget.initialDate ?? LocalDate.fromDateTime(now);
      _startMinute = ((now.hour + 1) % 24) * 60;
      final defaultOffset = ref.read(userProvider).value?.defaultReminderOffset;
      if (defaultOffset != null) _reminders = {defaultOffset};
      return;
    }

    final task = existing.task;
    final start = tz.TZDateTime.from(existing.occurrence.scheduledStart, _location);
    _title.text = task.title;
    _notes.text = task.notes ?? '';
    _date = LocalDate.fromDateTime(start);
    _startMinute = start.hour * 60 + start.minute;
    _duration = existing.occurrence.scheduledEnd
        .difference(existing.occurrence.scheduledStart)
        .inMinutes;
    _priority = Priority.values.byName(task.priority);
    _categoryId = task.categoryId;
    _loading = true;
    _loadSeries(task.id);
  }

  Future<void> _loadSeries(String taskId) async {
    final repo = ref.read(taskRepositoryProvider);
    final rule = await repo.ruleFor(taskId);
    final offsets = await repo.reminderOffsetsFor(taskId);
    if (!mounted) return;
    setState(() {
      _originalRule = rule;
      _repeat = _presetOf(rule);
      _reminders = offsets.toSet();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  static _Repeat _presetOf(RecurrenceRule? rule) {
    if (rule == null) return _Repeat.none;
    if (rule.interval != 1 || rule.count != null) return _Repeat.custom;
    return switch (rule.frequency) {
      Frequency.daily => _Repeat.daily,
      Frequency.monthly => _Repeat.monthly,
      Frequency.weekly when rule.byWeekdays.isEmpty => _Repeat.weekly,
      Frequency.weekly
          when rule.byWeekdays.length == 5 && !rule.byWeekdays.contains(6) &&
              !rule.byWeekdays.contains(7) =>
        _Repeat.weekdays,
      Frequency.weekly => _Repeat.custom,
    };
  }

  RecurrenceRule? _ruleFromPreset() => switch (_repeat) {
        _Repeat.none => null,
        _Repeat.daily => RecurrenceRule(frequency: Frequency.daily),
        _Repeat.weekdays => RecurrenceRule.weekdays(),
        _Repeat.weekly => RecurrenceRule(frequency: Frequency.weekly),
        _Repeat.monthly => RecurrenceRule(frequency: Frequency.monthly),
        _Repeat.custom => _originalRule,
      };

  Future<_Scope?> _askScope() {
    final l = AppLocalizations.of(context);
    return showDialog<_Scope>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l.applyToWhich),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _Scope.single),
            child: Text(l.onlyThisOne),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, _Scope.series),
            child: Text(l.wholeSeries),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = ref.read(taskRepositoryProvider);
    final existing = widget.existing;

    var scope = _Scope.series;
    if (existing != null && _canEditSingle) {
      final picked = await _askScope();
      if (picked == null) return;
      scope = picked;
    }

    setState(() => _saving = true);
    try {
      if (existing != null && scope == _Scope.single) {
        await repo.rescheduleOccurrence(
          existing.occurrence.id,
          newStartUtc: wallClockToUtc(_date, _startMinute, _location),
          durationMin: _duration,
        );
      } else {
        final occurrenceDate = existing == null
            ? null
            : LocalDate.fromDateTime(tz.TZDateTime.from(
                existing.occurrence.scheduledStart, _location));
        // Keep the series anchor unless the user moved the date.
        final startDate = existing != null && _date == occurrenceDate
            ? LocalDate.parse(existing.task.startDate)
            : _date;
        final draft = TaskDraft(
          title: _title.text,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          startDate: startDate,
          startMinute: _startMinute,
          durationMin: _duration,
          timezone: ref.read(timezoneProvider),
          priority: _priority,
          rule: _ruleFromPreset(),
          reminderOffsets: _reminders.toList()..sort(),
          categoryId: _categoryId,
        );
        if (existing == null) {
          await repo.createTask(draft);
        } else {
          await repo.updateSeries(existing.task.id, draft);
        }
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing!;
    final repo = ref.read(taskRepositoryProvider);
    final scope = _canEditSingle ? await _askScope() : _Scope.series;
    if (scope == null) return;
    if (scope == _Scope.single) {
      await repo.deleteOccurrence(existing.occurrence.id);
    } else {
      await repo.deleteSeries(existing.task.id);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = LocalDate.fromDateTime(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startMinute ~/ 60, minute: _startMinute % 60),
    );
    if (picked != null) {
      setState(() => _startMinute = picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ethiopian = ref.watch(userProvider).value?.calendarType == 'ethiopian';
    final durations = {..._durations, _duration}.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l.editTask : l.newTask),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: Text(l.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _title,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: l.fieldTitle),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? l.titleRequired : null,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(l.fieldDate),
                    subtitle: Text(
                        formatLongDate(context, _date, ethiopian: ethiopian)),
                    onTap: _pickDate,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: Text(l.fieldTime),
                    subtitle: Text(formatMinuteOfDay(context, _startMinute)),
                    onTap: _pickTime,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _duration,
                    decoration: InputDecoration(
                        labelText: l.fieldDuration,
                        prefixIcon: const Icon(Icons.timelapse)),
                    items: [
                      for (final d in durations)
                        DropdownMenuItem(
                            value: d, child: Text(l.durationMinutes(d))),
                    ],
                    onChanged: (v) => setState(() => _duration = v!),
                  ),
                  const SizedBox(height: 16),
                  _CategoryField(
                    value: _categoryId,
                    onChanged: (id) => setState(() => _categoryId = id),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<_Repeat>(
                    initialValue: _repeat,
                    decoration: InputDecoration(
                        labelText: l.fieldRepeat,
                        prefixIcon: const Icon(Icons.repeat)),
                    items: [
                      for (final r in _Repeat.values)
                        if (r != _Repeat.custom || _repeat == _Repeat.custom)
                          DropdownMenuItem(value: r, child: Text(_repeatLabel(l, r))),
                    ],
                    onChanged: (v) => setState(() => _repeat = v!),
                  ),
                  const SizedBox(height: 16),
                  Text(l.fieldPriority,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<Priority>(
                    segments: [
                      ButtonSegment(value: Priority.low, label: Text(l.priorityLow)),
                      ButtonSegment(
                          value: Priority.normal, label: Text(l.priorityNormal)),
                      ButtonSegment(value: Priority.high, label: Text(l.priorityHigh)),
                    ],
                    selected: {_priority},
                    onSelectionChanged: (s) => setState(() => _priority = s.first),
                  ),
                  const SizedBox(height: 16),
                  Text(l.fieldReminders,
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final offset in {...SchedulingPolicy.reminderChoices, ..._reminders}.toList()..sort())
                        FilterChip(
                          label: Text(offset == 0
                              ? l.reminderAtStart
                              : l.reminderBefore(offset)),
                          selected: _reminders.contains(offset),
                          onSelected: (on) => setState(() => on
                              ? _reminders.add(offset)
                              : _reminders.remove(offset)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(labelText: l.fieldNotes),
                  ),
                ],
              ),
            ),
    );
  }

  static String _repeatLabel(AppLocalizations l, _Repeat r) => switch (r) {
        _Repeat.none => l.repeatNone,
        _Repeat.daily => l.repeatDaily,
        _Repeat.weekdays => l.repeatWeekdays,
        _Repeat.weekly => l.repeatWeekly,
        _Repeat.monthly => l.repeatMonthly,
        _Repeat.custom => '…',
      };
}

/// Category picker (FR-19).
class _CategoryField extends ConsumerWidget {
  const _CategoryField({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    // A category deleted elsewhere falls back to "none".
    final current =
        categories.any((c) => c.id == value) ? value : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('category-$current-${categories.length}'),
      initialValue: current,
      isExpanded: true,
      decoration: InputDecoration(
          labelText: l.fieldCategory, prefixIcon: const Icon(Icons.label_outline)),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(l.categoryNone)),
        for (final c in categories)
          DropdownMenuItem<String?>(
            value: c.id,
            child: Row(children: [
              Icon(CategoryStyle.icon(c.icon), color: Color(c.color), size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
