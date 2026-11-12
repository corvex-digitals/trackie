import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../data/task_repository.dart';
import '../domain/scheduling.dart';

/// Sets an occurrence's status and offers Undo (FR-14). Shared by swipe,
/// screen-reader actions and the occurrence sheet.
Future<void> markOccurrence(
  BuildContext context,
  WidgetRef ref,
  OccurrenceView item,
  OccurrenceStatus status,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final repo = ref.read(taskRepositoryProvider);
  final previous = item.status;
  await repo.setStatus(item.occurrence.id, status);

  final message = switch (status) {
    OccurrenceStatus.done => l.markedDone,
    OccurrenceStatus.skipped => l.markedSkipped,
    _ => null,
  };
  if (message == null || messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () => repo.setStatus(item.occurrence.id, previous),
      ),
    ));
}

String statusLabel(AppLocalizations l, OccurrenceStatus status) =>
    switch (status) {
      OccurrenceStatus.pending => l.statusPending,
      OccurrenceStatus.done => l.statusDone,
      OccurrenceStatus.skipped => l.statusSkipped,
      OccurrenceStatus.missed => l.statusMissed,
    };
