import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android battery-optimisation status and shortcuts to the system settings
/// screens a user needs for reliable reminders (NFR-01). Implemented in
/// `MainActivity.kt`; on iOS every call is a no-op.
class SystemSettings {
  const SystemSettings();

  static const _channel = MethodChannel('trackie/system');

  bool get _android => Platform.isAndroid;

  /// True when Android will not defer the app's alarms to save battery.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_android) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the system list where the app can be set to "Unrestricted" /
  /// "Don't optimise".
  Future<void> openBatteryOptimizationSettings() async {
    if (_android) await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
  }

  /// Opens the app's own system settings page (autostart, notifications...).
  Future<void> openAppSettings() async {
    if (_android) await _channel.invokeMethod<void>('openAppSettings');
  }

  /// Lower-case device manufacturer, e.g. `samsung`, `xiaomi`, `tecno`.
  Future<String> manufacturer() async {
    if (!_android) return 'apple';
    try {
      return (await _channel.invokeMethod<String>('manufacturer') ?? '')
          .toLowerCase();
    } on PlatformException {
      return '';
    }
  }
}

/// Phone makers known to stop background alarms unless the user allows the
/// app to auto-start / run in the background.
const aggressiveBatteryMakers = {
  'xiaomi', 'redmi', 'poco', 'tecno', 'infinix', 'itel', 'oppo', 'realme',
  'vivo', 'huawei', 'honor', 'oneplus', 'samsung',
};
