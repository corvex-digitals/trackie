import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/providers.dart';
import 'core/errors/error_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHandlers();

  final Services services;
  try {
    services = await Services.create();
  } catch (error, stack) {
    // Without this the app would sit on the splash screen forever.
    reportError(error, stack, fatal: true);
    runApp(const _StartupFailedApp());
    return;
  }

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TrackieApp(),
    ),
  );
}

/// Shown when the database or notifications can't be set up. Localisations
/// aren't loaded yet at this point, so the text is fixed.
class _StartupFailedApp extends StatelessWidget {
  const _StartupFailedApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Trackie could not start.\n\n'
              'Please close the app and open it again. If this keeps '
              'happening, restart your phone.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
