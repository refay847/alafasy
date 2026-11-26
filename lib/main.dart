import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'features/quran/data/datasources/quran_local_data_source.dart';
import 'features/quran/data/services/quran_audio_service.dart';
import 'features/quran/presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.alafasy.audio',
    androidNotificationChannelName: 'Quran Audio',
    androidNotificationChannelDescription:
        'Quran audio playback controls',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
    fastForwardInterval: const Duration(seconds: 15),
    rewindInterval: const Duration(seconds: 15),
  );

  final audioService = QuranAudioService(
    surahs: QuranLocalDataSource.surahs,
  );

  // Don't block runApp on initialize(); let the widget tree show a
  // splash/error state instead of a blank screen if something fails.
  runApp(
    QuranApp(
      audioService: audioService,
    ),
  );
}

class QuranApp extends StatefulWidget {
  const QuranApp({
    super.key,
    required this.audioService,
  });

  final QuranAudioService audioService;

  @override
  State<QuranApp> createState() => _QuranAppState();
}

class _QuranAppState extends State<QuranApp> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = widget.audioService.initialize();
  }

  @override
  void dispose() {
    widget.audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'القرآن الكريم',

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFFFCF5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC49A3A),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF8A6A24),
          elevation: 0,
          centerTitle: true,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFC49A3A),
          inactiveTrackColor: const Color(0xFFE9DFC6),
          thumbColor: const Color(0xFFC49A3A),
          overlayColor: const Color(0x20C49A3A),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),

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
            return _ErrorScreen(error: snapshot.error);
          }

          return HomePage(
            audioService: widget.audioService,
            surahs: QuranLocalDataSource.surahs,
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFC49A3A),
            ),
            SizedBox(height: 16),
            Text('جاري التحميل...'),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل الملفات الصوتية',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}