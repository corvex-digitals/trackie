import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Where uncaught errors go. Replace the body of [reportError] with a crash
/// reporter (e.g. `FirebaseCrashlytics.instance.recordError(error, stack,
/// fatal: fatal)`) once one is configured; everything else already routes
/// through it.
void reportError(Object error, StackTrace? stack, {bool fatal = false}) {
  developer.log(
    fatal ? 'Uncaught error' : 'Error',
    name: 'trackie',
    error: error,
    stackTrace: stack,
    level: fatal ? 1000 : 900,
  );
}

/// Routes framework errors (build/layout/paint) and uncaught async errors to
/// [reportError]. Call once at the start of `main`, after
/// `WidgetsFlutterBinding.ensureInitialized()`.
void installErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // Keeps the red error screen and console dump in debug builds.
    previous?.call(details);
    reportError(details.exception, details.stack, fatal: !details.silent);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reportError(error, stack, fatal: true);
    return true;
  };
}
