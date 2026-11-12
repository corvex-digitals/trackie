import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/date_display.dart';
import '../../../core/utils/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/scheduling.dart';
import '../../tasks/presentation/occurrence_actions.dart';
import '../../tasks/presentation/occurrence_sheet.dart';

/// Hour-by-hour timeline of one day (FR-12) with a current-time line when
/// the day is today. Swipe right = done, swipe left = skip (FR-14); tap for
/// all actions.
class DayTimeline extends StatefulWidget {
  const DayTimeline({
    super.key,
    required this.items,
    required this.day,
    required this.location,
  });

  final List<OccurrenceView> items;
  final LocalDate day;
  final tz.Location location;

  static const hourHeight = 64.0;

  @override
  State<DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<DayTimeline> {
  Timer? _ticker;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final now = tz.TZDateTime.now(widget.location);
    final firstItem = widget.items.firstOrNull;
    final focusHour = _isToday
        ? now.hour
        : firstItem == null
            ? 8
            : tz.TZDateTime.from(firstItem.occurrence.scheduledStart, widget.location).hour;
    _scroll = ScrollController(
        initialScrollOffset: math.max(0, (focusHour - 1) * DayTimeline.hourHeight));
    // Moves the current-time line.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_isToday) setState(() {});
    });
  }

  bool get _isToday =>
      LocalDate.fromDateTime(tz.TZDateTime.now(widget.location)) == widget.day;

  @override
  void dispose() {
    _ticker?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        controller: _scroll,
        child: _TimelineBody(
          items: widget.items,
          day: widget.day,
          location: widget.location,
          now: _isToday ? DateTime.now().toUtc() : null,
        ),
      );
}

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({
    required this.items,
    required this.day,
    required this.location,
    required this.now,
  });

  final List<OccurrenceView> items;
  final LocalDate day;
  final tz.Location location;
  final DateTime? now;

  static const _gutter = 56.0;
  static const _hour = DayTimeline.hourHeight;

  double _offsetOf(DateTime utc) {
    final dayStart = wallClockToUtc(day, 0, location);
    final minutes = utc.difference(dayStart).inMinutes.clamp(0, 24 * 60);
    return minutes * _hour / 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lanes = _assignLanes(items);
    final laneCount = lanes.values.fold(0, (m, v) => math.max(m, v + 1));

    return LayoutBuilder(builder: (context, constraints) {
      final laneWidth =
          (constraints.maxWidth - _gutter - 8) / math.max(1, laneCount);
      return SizedBox(
        height: _hour * 24,
        child: Stack(
          children: [
            for (var h = 0; h < 24; h++)
              Positioned(
                top: h * _hour,
                left: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _gutter,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Text(formatMinuteOfDay(context, h * 60),
                              style: theme.textTheme.labelSmall),
                        ),
                      ),
                      Expanded(child: Divider(height: 1, color: theme.dividerColor)),
                    ],
                  ),
                ),
              ),
            for (final item in items)
              Positioned(
                top: _offsetOf(item.occurrence.scheduledStart),
                left: _gutter + lanes[item.occurrence.id]! * laneWidth,
                width: laneWidth - 4,
                height: math.max(
                  48, // minimum touch target (NFR-09)
                  _offsetOf(item.occurrence.scheduledEnd) -
                      _offsetOf(item.occurrence.scheduledStart),
                ),
                child: OccurrenceCard(item: item, location: location),
              ),
            if (now case final now?)
              Positioned(
                top: _offsetOf(now) - 1,
                left: _gutter - 6,
                right: 0,
                child: ExcludeSemantics(
                  child: Row(children: [
                    CircleAvatar(radius: 5, backgroundColor: theme.colorScheme.error),
                    Expanded(
                        child: Container(height: 2, color: theme.colorScheme.error)),
                  ]),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Greedy lane assignment so overlapping tasks sit side by side.
  static Map<String, int> _assignLanes(List<OccurrenceView> items) {
    final laneEnds = <DateTime>[];
    final result = <String, int>{};
    for (final item in items) {
      final o = item.occurrence;
      var lane = laneEnds.indexWhere((end) => !end.isAfter(o.scheduledStart));
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(o.scheduledEnd);
      } else {
        laneEnds[lane] = o.scheduledEnd;
      }
      result[o.id] = lane;
    }
    return result;
  }
}

/// One occurrence on the timeline: category colour stripe, status styling,
/// swipe actions and the same actions for screen readers (NFR-10).
class OccurrenceCard extends ConsumerWidget {
  const OccurrenceCard({super.key, required this.item, required this.location});
  final OccurrenceView item;
  final tz.Location location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = item.status;
    final start = tz.TZDateTime.from(item.occurrence.scheduledStart, location);
    final time = formatTime(context, start);
    final accent = item.category == null ? scheme.primary : Color(item.category!.color);

    final (Color bg, Color fg, String? badge) = switch (status) {
      OccurrenceStatus.done => (scheme.secondaryContainer, scheme.onSecondaryContainer, l.statusDone),
      OccurrenceStatus.skipped => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, l.statusSkipped),
      OccurrenceStatus.missed => (scheme.errorContainer, scheme.onErrorContainer, l.statusMissed),
      OccurrenceStatus.pending => (scheme.primaryContainer, scheme.onPrimaryContainer, null),
    };

    Future<bool> mark(OccurrenceStatus s) async {
      await markOccurrence(context, ref, item, s);
      return false; // keep the card; it re-renders with its new status
    }

    final card = Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => OccurrenceSheet.show(context, item),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          // One rich text block rather than a Column, so short cards and
          // large system font sizes clip instead of overflowing.
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: item.task.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  decoration: status == OccurrenceStatus.done
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
              TextSpan(
                text: '\n${[time, ?badge].join(' · ')}',
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    final semantic = Semantics(
      container: true,
      button: true,
      label: l.semanticsOccurrence(item.task.title, time, statusLabel(l, status)),
      customSemanticsActions: item.isProjected
          ? null
          : {
              CustomSemanticsAction(label: l.actionDone): () =>
                  mark(OccurrenceStatus.done),
              CustomSemanticsAction(label: l.actionSkip): () =>
                  mark(OccurrenceStatus.skipped),
            },
      child: ExcludeSemantics(child: card),
    );

    if (item.isProjected) return semantic;

    return Dismissible(
      key: ValueKey('occ-${item.occurrence.id}'),
      confirmDismiss: (direction) => direction == DismissDirection.startToEnd
          ? mark(OccurrenceStatus.done)
          : mark(OccurrenceStatus.skipped),
      background: _SwipeBackground(
          icon: Icons.check, label: l.actionDone, color: scheme.secondary,
          alignment: Alignment.centerLeft),
      secondaryBackground: _SwipeBackground(
          icon: Icons.redo, label: l.actionSkip, color: scheme.outline,
          alignment: Alignment.centerRight),
      child: semantic,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(8)),
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white)),
          ),
        ]),
      );
}
