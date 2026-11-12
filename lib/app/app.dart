import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/background/maintenance_job.dart';
import '../core/database/app_database.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/tasks/presentation/occurrence_sheet.dart';
import '../l10n/app_localizations.dart';
import 'home_shell.dart';
import 'providers.dart';

class TrackieApp extends ConsumerStatefulWidget {
  const TrackieApp({super.key});

  @override
  ConsumerState<TrackieApp> createState() => _TrackieAppState();
}

class _TrackieAppState extends ConsumerState<TrackieApp>
    with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final services = ref.read(servicesProvider);
    _taps = services.notificationTaps.listen(_openOccurrence);

    // Heavy work waits for the first frame so cold start stays fast (NFR-03).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await services.maintain();
      await scheduleMaintenanceJob(ref.read(locationProvider));
      final launched = services.launchPayload;
      services.launchPayload = null;
      if (launched != null) await _openOccurrence(launched);
    });
  }

  @override
  void dispose() {
    _taps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back after hours or days, or from a system settings screen: follow any
    // time-zone change, mark missed, roll the window forward, re-register
    // alarms, and re-check permissions.
    if (state == AppLifecycleState.resumed) {
      ref.read(servicesProvider).maintain();
      ref.invalidate(reminderHealthProvider);
    }
  }

  /// Opens the actions for a tapped notification's task.
  Future<void> _openOccurrence(String occurrenceId) async {
    if (ref.read(userProvider).value?.onboardingCompleted != true) return;
    final item = await ref.read(taskRepositoryProvider).occurrenceById(occurrenceId);
    final context = _navigatorKey.currentState?.overlay?.context;
    if (item == null || context == null || !context.mounted) return;
    await OccurrenceSheet.show(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider).value;
    const seed = Color(0xFF2E7D6B);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: user == null ? null : Locale(user.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: switch (user?.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      home: switch (user) {
        null => const Scaffold(body: Center(child: CircularProgressIndicator())),
        User(onboardingCompleted: false) => const OnboardingScreen(),
        _ => const HomeShell(),
      },
    );
  }
}
