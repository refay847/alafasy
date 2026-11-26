import 'dart:async';
import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/theme/app_theme.dart';
import 'features/quran/data/datasources/quran_local_data_source.dart';
import 'features/quran/data/datasources/quran_preferences.dart';
import 'features/quran/data/services/quran_audio_service.dart';
import 'features/quran/presentation/pages/home_page.dart';
import 'features/quran/presentation/state/quran_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows) {
    // Desktop has no native just_audio backend, so use media_kit.
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
  } else {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.alafasy.audio',
      androidNotificationChannelName: 'Quran Audio',
      androidNotificationChannelDescription: 'Quran audio playback controls',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: const Duration(seconds: 15),
      rewindInterval: const Duration(seconds: 15),
    );
  }

  final preferences = await QuranPreferences.create();

  final controller = QuranController(preferences: preferences);

  final audioService = QuranAudioService(
    surahs: QuranLocalDataSource.surahs,
    preferences: preferences,
  );

  // Don't block runApp on initialize(); the widget tree shows a loading /
  // error state instead of a blank screen if something fails.
  runApp(
    QuranApp(
      audioService: audioService,
      controller: controller,
    ),
  );
}

class QuranApp extends StatefulWidget {
  const QuranApp({
    super.key,
    required this.audioService,
    required this.controller,
  });

  final QuranAudioService audioService;
  final QuranController controller;

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late Future<void> _initFuture;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();

    _initFuture = widget.audioService.initialize();

    // Playback errors surface as a friendly snackbar from anywhere in the app.
    _errorSubscription = widget.audioService.errors.listen((message) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    widget.audioService.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _initFuture = widget.audioService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'القرآن الكريم',
          scaffoldMessengerKey: _messengerKey,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: widget.controller.themeMode,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingScreen();
              }

              if (snapshot.hasError) {
                return _ErrorScreen(error: snapshot.error, onRetry: _retry);
              }

              return HomePage(
                audioService: widget.audioService,
                surahs: QuranLocalDataSource.surahs,
                controller: widget.controller,
              );
            },
          ),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'القرآن الكريم',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colors.goldText,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: colors.gold),
            const SizedBox(height: 16),
            Text('جاري التحميل...', style: TextStyle(color: colors.muted)),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل الملفات الصوتية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}