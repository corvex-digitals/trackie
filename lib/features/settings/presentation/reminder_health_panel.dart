import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/notifications/local_notification_gateway.dart';
import '../../../l10n/app_localizations.dart';

/// The checks that decide whether reminders arrive on time (NFR-01), each
/// with a button to fix it. Used in onboarding and Settings. Status is
/// re-checked when the app resumes from the system settings screens.
class ReminderHealthPanel extends ConsumerWidget {
  const ReminderHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final health = ref.watch(reminderHealthProvider);
    LocalNotificationGateway gateway() => ref.read(servicesProvider).notifications;

    void recheck() => ref.invalidate(reminderHealthProvider);

    return switch (health) {
      AsyncData(:final value) => Column(
          children: [
            _Check(
              icon: Icons.notifications_outlined,
              title: l.permNotificationsTitle,
              body: l.permNotificationsBody,
              ok: value.notificationsAllowed,
              action: l.permAllow,
              onFix: () async {
                final granted = await gateway().requestNotificationPermission();
                // Denied twice, Android stops showing the prompt: send the
                // user to the app's notification settings instead.
                if (!granted) await gateway().openAppSettings();
                recheck();
              },
            ),
            if (Platform.isAndroid) ...[
              _Check(
                icon: Icons.alarm,
                title: l.permExactTitle,
                body: l.permExactBody,
                ok: value.exactAlarmsAllowed,
                action: l.permAllow,
                onFix: () async {
                  await gateway().requestExactAlarmPermission();
                  recheck();
                },
              ),
              _Check(
                icon: Icons.battery_saver_outlined,
                title: l.permBatteryTitle,
                body: l.permBatteryBody,
                ok: value.batteryUnrestricted,
                action: l.permOpenSettings,
                onFix: () => gateway().openBatterySettings(),
              ),
              if (value.needsAutostartTip)
                _Check(
                  icon: Icons.restart_alt,
                  title: l.autostartTitle,
                  body: l.autostartBody(_makerName(value)),
                  ok: null,
                  action: l.permOpenSettings,
                  onFix: () => gateway().openAppSettings(),
                ),
            ],
          ],
        ),
      AsyncError(:final error) => Text('$error'),
      _ => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }

  static String _makerName(ReminderHealth h) => h.manufacturer.isEmpty
      ? ''
      : h.manufacturer[0].toUpperCase() + h.manufacturer.substring(1);
}

class _Check extends StatelessWidget {
  const _Check({
    required this.icon,
    required this.title,
    required this.body,
    required this.ok,
    required this.action,
    required this.onFix,
  });

  final IconData icon;
  final String title;
  final String body;

  /// null = advice that cannot be verified (always offers the button).
  final bool? ok;
  final String action;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        ok == true ? Icons.check_circle : icon,
        color: ok == true ? scheme.primary : (ok == false ? scheme.error : null),
      ),
      title: Text(title),
      subtitle: Text(ok == true ? l.permGranted : body),
      isThreeLine: ok != true,
      trailing: ok == true
          ? null
          : FilledButton.tonal(onPressed: onFix, child: Text(action)),
    );
  }
}
