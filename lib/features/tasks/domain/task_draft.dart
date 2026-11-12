import '../../../core/utils/local_date.dart';
import 'recurrence.dart';

enum Priority { low, normal, high }

/// What the task editor produces: everything needed to create or update a
/// task series (FR-03, FR-04, FR-07).
class TaskDraft {
  TaskDraft({
    required this.title,
    required this.startDate,
    required this.startMinute,
    required this.timezone,
    this.durationMin = 30,
    this.notes,
    this.categoryId,
    this.priority = Priority.normal,
    this.isAllDay = false,
    this.rule,
    this.reminderOffsets = const [0],
  }) {
    if (title.trim().isEmpty) throw ArgumentError('Title is required');
    if (startMinute < 0 || startMinute >= 24 * 60) {
      throw ArgumentError.value(startMinute, 'startMinute');
    }
    if (durationMin < 0) throw ArgumentError.value(durationMin, 'durationMin');
    if (reminderOffsets.any((o) => o < 0)) {
      throw ArgumentError('Reminder offsets must be >= 0 minutes before start');
    }
  }

  final String title;
  final String? notes;
  final LocalDate startDate;

  /// Minutes since local midnight.
  final int startMinute;
  final int durationMin;

  /// IANA zone, e.g. `Africa/Addis_Ababa`.
  final String timezone;
  final String? categoryId;
  final Priority priority;
  final bool isAllDay;
  final RecurrenceRule? rule;

  /// Minutes before start for each alert; 0 = at start.
  final List<int> reminderOffsets;
}
