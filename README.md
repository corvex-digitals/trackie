# Trackie

Offline-first daily activity tracker and reminder app for Android and iOS
(Flutter). Built from *Daily Activity Tracker & Reminder App — System
Requirements and Design* (Nov 2, 2026).

## Getting started

```bash
flutter pub get
dart run build_runner build      # Drift database code (lib/core/database/*.g.dart)
flutter gen-l10n                 # also runs automatically on build
flutter test                     # unit + widget tests
flutter run                      # on a real Android device for notification testing
```

Re-run `build_runner` after changing `lib/core/database/tables.dart`.

## Architecture

The UI talks only to repositories and providers. The local SQLite database is
the source of truth, and every alert is handed to the OS so it fires even when
the app is killed.

```
UI (screens, Riverpod providers)
  └─ TaskRepository ─── materialises occurrences, tracking, maintenance
       ├─ AppDatabase (Drift / SQLite)
       └─ ReminderScheduler ─── diffs wanted alerts vs scheduled_notifications
            └─ NotificationGateway → flutter_local_notifications → OS alarms
```

| Path | What it holds |
| --- | --- |
| `lib/core/database/` | Drift tables for every entity in section 6 of the spec |
| `lib/core/notifications/` | `ReminderScheduler` (idempotent alarm sync), the OS gateway, permission checks, and the Done/Snooze action handler |
| `lib/core/background/` | Android maintenance job (midnight, then every 6 hours, survives reboot) |
| `lib/core/platform/` | Battery-optimisation status and settings shortcuts (native side in `MainActivity.kt`) |
| `lib/core/utils/` | `LocalDate`, Ethiopian calendar conversion, Gregorian/Ethiopian month grids |
| `lib/features/tasks/domain/` | Recurrence rules, scheduling policy, `TaskDraft` (pure Dart) |
| `lib/features/tasks/data/` | `TaskRepository` |
| `lib/features/*/presentation/` | Screens |
| `lib/l10n/` | English and Amharic strings |

### Key design decisions

- **Rolling window.** Occurrences are stored only for today + 14 days. The
  calendar projects later dates from each series on the fly, without storing
  them. `Services.maintain()` runs after the first frame, on resume, and from
  the Android background job. It follows device time-zone changes, marks
  overdue occurrences missed, extends the window, and calls
  `ReminderScheduler.resync()`.
- **Idempotent alarm sync.** `resync()` computes the alerts that should exist
  and registers or cancels only the difference. It is safe to call any number
  of times.
- **Alarm cap.** Android drops alarms beyond about 500 per app, and iOS keeps
  only 64 pending notifications. The scheduler registers only the nearest 400
  on Android and 60 on iOS (`SchedulingPolicy`).
- **Time-zone changes.** Tasks are wall-clock plans, so after a time-zone
  change upcoming occurrences move to the same local time in the new zone.
  History and individually edited occurrences keep their original times.
- **Single-occurrence edits.** An occurrence edited or deleted on its own is
  flagged `is_exception`, so series edits and window extension leave it
  alone. Deleted occurrences are soft-deleted and never regenerated.
- **Times.** Recurrence works on local calendar dates in the task's IANA
  zone. Occurrences store UTC instants, and Drift stores datetimes as
  ISO-8601 text (`build.yaml`) so the UTC flag survives a round trip.
- **Missed status.** A pending occurrence becomes missed 30 minutes after its
  scheduled end.
- **Exact alarms.** The app requests `SCHEDULE_EXACT_ALARM` and falls back to
  inexact alarms if it is denied, so a reminder may be late but is never lost.

## Status against the spec

Version 1 ("Must") is feature-complete:
- FR-01: local profile, no account needed
- FR-03 and FR-04: tasks with recurrence (daily, weekdays, weekly, monthly, custom interval, end date, count)
- FR-05: edit or delete one occurrence or the whole series
- FR-07: multiple reminders per task, with a configurable default
- FR-08: reminders survive app kill and reboot. The plugin's boot receiver
  restores alarms, and the background job and app start resync them.
- FR-09: Done, Snooze 10 min and Snooze 30 min on the notification (Android
  allows 3 buttons). Tapping the notification opens the task, where 5, 10
  and 30 min are offered.
- FR-12: Today timeline, week view, month view, and a day view for any date
- FR-14: done, skipped and missed tracking (swipe, action sheet, notification)
- FR-19: categories with name, colour and icon, plus 4 starter categories
- FR-20: language (English/Amharic), calendar (Gregorian/Ethiopian, including
  Ethiopian month grids), theme, default reminder
- Section 8 onboarding: language, calendar, notification and exact-alarm
  permissions, battery-optimisation and OEM auto-start guidance
- NFR-08: delete all data from Settings
- NFR-10: swipe actions are also available as screen-reader actions

Not built (version 2 and later): sign-in and sync, insights, routines, quiet
hours, home-screen widget, rescheduling to a suggested free slot,
natural-language input, calendar import/export, location reminders.

## Known gaps and risks

- **iOS background work.** iOS has no equivalent of the Android maintenance
  job, so the window rolls and missed status updates only when the app is
  opened. Up to 60 alerts are registered ahead.
- **Amharic strings** (`lib/l10n/app_am.arb`, `ReminderScheduler._Strings`,
  `NotificationLabels`) are a first draft and need review by a native
  speaker.
- **Device testing** on Samsung, Tecno, Infinix and Xiaomi with battery saver
  on is still the only way to verify NFR-01.
- **Release setup** is still to do: upload keystore and signing, final
  application ID, app icon and splash screen, a schema snapshot before the
  first release (`dart run drift_dev schema dump`), and Crashlytics.
