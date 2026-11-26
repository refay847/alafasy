import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_logo.dart';
import 'features/quran/data/datasources/quran_local_data_source.dart';
import 'features/quran/data/datasources/quran_preferences.dart';
import 'features/quran/data/services/notification_artwork.dart';
import 'features/quran/data/services/quran_audio_handler.dart';
import 'features/quran/data/services/quran_audio_service.dart';
import 'features/quran/presentation/pages/home_page.dart';
import 'features/quran/presentation/state/quran_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await QuranPreferences.create();

  final controller = QuranController(preferences: preferences);

  final audioService = QuranAudioService(
    surahs: QuranLocalDataSource.surahs,
    preferences: preferences,
  );

  if (Platform.isLinux || Platform.isWindows) {
    // Desktop has no native just_audio backend, so use media_kit.
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
  } else {
    // Artwork for the notification shade / lock screen (rendered once, cached).
    final artworkUri = await NotificationArtwork.ensureCreated();

    // Custom handler = custom notification buttons:
    // favorite | previous | play/pause | next | close (X)
    await AudioService.init<QuranAudioHandler>(
      builder: () => QuranAudioHandler(
        audio: audioService,
        surahs: QuranLocalDataSource.surahs,
        isFavorite: controller.isFavorite,
        onToggleFavorite: controller.toggleFavorite,
        favoritesListenable: controller,
        artworkUri: artworkUri,
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.alafasy.audio',
        androidNotificationChannelName: 'القرآن الكريم',
        androidNotificationChannelDescription: 'التحكم في تشغيل القرآن الكريم',
        // Gold accent for the media notification.
        notificationColor: Color(0xFFC49A3A),
        // Monochrome status-bar icon (android/app/src/main/res/drawable).
        androidNotificationIcon: 'drawable/ic_stat_quran',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }

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

class _QuranAppState extends State<QuranApp> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late Future<void> _initFuture;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OS can kill the app right after it goes to the background without
    // calling dispose(), so save the current surah + position right now.
    if (state != AppLifecycleState.resumed) {
      unawaited(widget.audioService.persistNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

/// Always uses the dark brand look, exactly like the native splash screen,
/// so the hand-off from the native splash to Flutter has no visible jump.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final colors = context.colors;

          return Scaffold(
            body: SafeArea(
              child: Stack(
                children: [
                  // Same position and size as the native splash logo.
                  const Center(child: AppLogo(size: 140)),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 56,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'القرآن الكريم',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.goldText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'بصوت الشيخ مشاري العفاسي',
                          style: TextStyle(color: colors.muted, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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