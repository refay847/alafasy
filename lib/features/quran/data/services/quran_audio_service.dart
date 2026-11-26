import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/surah.dart';
import '../datasources/quran_preferences.dart';

class SleepTimerState {
  const SleepTimerState.timed(this.remaining) : endOfSurah = false;

  const SleepTimerState.endOfSurah()
      : remaining = null,
        endOfSurah = true;

  final Duration? remaining;
  final bool endOfSurah;
}

class QuranAudioService {
  QuranAudioService({
    required this.surahs,
    required this.preferences,
  });

  final List<Surah> surahs;
  final QuranPreferences preferences;

  final AudioPlayer player = AudioPlayer();

  /// True once something has been played (or a previous session was restored).
  /// Drives the visibility of the mini player.
  final ValueNotifier<bool> hasSession = ValueNotifier<bool>(false);

  /// Null when no sleep timer is active.
  final ValueNotifier<SleepTimerState?> sleepTimer =
      ValueNotifier<SleepTimerState?>(null);

  final StreamController<String> _errors =
      StreamController<String>.broadcast();

  Stream<String> get errors => _errors.stream;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Timer? _sleepTicker;
  bool _endOfSurahArmed = false;
  bool _listening = false;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initialize() async {
    final sources = surahs.map((surah) {
      return AudioSource.asset(
        surah.audioAsset,
        tag: MediaItem(
          id: surah.number.toString(),
          title: surah.arabicName,
          artist: 'مشاري بن راشد العفاسي',
          album: 'القرآن الكريم',
        ),
      );
    }).toList();

    final hasLastSession = preferences.hasLastSession;
    final savedIndex = preferences.lastIndex.clamp(0, surahs.length - 1).toInt();

    await player.setAudioSources(
      sources,
      preload: false,
      initialIndex: hasLastSession ? savedIndex : 0,
      initialPosition:
          hasLastSession ? Duration(milliseconds: preferences.lastPositionMs) : Duration.zero,
    );

    await player.setSpeed(preferences.speed);
    await player.setLoopMode(preferences.loopMode);

    if (preferences.shuffle) {
      await player.shuffle();
      await player.setShuffleModeEnabled(true);
    }

    hasSession.value = hasLastSession;

    _listen();
  }

  void _listen() {
    if (_listening) return;
    _listening = true;

    _subscriptions.addAll([
      player.positionStream.listen(_onPosition),
      player.currentIndexStream.listen(_onIndexChanged),
      // skip(1): the first event is the initial value, not a user pause.
      player.playingStream.skip(1).listen((playing) {
        if (!playing) unawaited(_saveProgress());
      }),
      player.playbackEventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          _errors.add('تعذر تشغيل هذه السورة، حاول مرة أخرى');
        },
      ),
    ]);
  }

  void _onIndexChanged(int? index) {
    if (index == null) return;

    if (index != preferences.lastIndex) {
      unawaited(preferences.setLastIndex(index));
      unawaited(preferences.setLastPositionMs(0));
    }
  }

  void _onPosition(Duration position) {
    // Persist progress at most every 5 seconds while playing.
    final now = DateTime.now();
    if (player.playing && now.difference(_lastSave) >= const Duration(seconds: 5)) {
      _lastSave = now;
      unawaited(preferences.setLastPositionMs(position.inMilliseconds));
    }

    // "Until end of surah" sleep timer.
    if (_endOfSurahArmed && player.playing) {
      final duration = player.duration;

      if (duration != null &&
          duration > Duration.zero &&
          duration - position <= const Duration(seconds: 1)) {
        unawaited(player.pause());
        cancelSleepTimer();
      }
    }
  }

  Future<void> _saveProgress() {
    return preferences.setLastPositionMs(player.position.inMilliseconds);
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  Future<void> playSurah(int index) async {
    if (index < 0 || index >= surahs.length) return;

    hasSession.value = true;

    final isDifferent = player.currentIndex != index;

    if (isDifferent) {
      await preferences.setLastPositionMs(0);
      await preferences.setLastIndex(index);
      await player.seek(Duration.zero, index: index);
    } else if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }

    // Do NOT await play(): its Future only completes when playback pauses
    // or finishes, which would block the caller for the whole surah.
    if (!player.playing) {
      unawaited(player.play());
    }
  }

  Future<void> togglePlayPause() async {
    hasSession.value = true;

    if (player.playing) {
      await player.pause();
      return;
    }

    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }

    unawaited(player.play());
  }

  Future<void> pause() => player.pause();

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> previous() async {
    // just_audio restarts the current track if more than 3s have played.
    await player.seekToPrevious();
  }

  Future<void> seek(Duration position) => player.seek(position);

  Future<void> forward15() async {
    final duration = player.duration;
    if (duration == null) return;

    final target = player.position + const Duration(seconds: 15);
    await player.seek(target > duration ? duration : target);
  }

  Future<void> rewind15() async {
    final target = player.position - const Duration(seconds: 15);
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> setVolume(double volume) => player.setVolume(volume);

  Future<void> setSpeed(double speed) async {
    await player.setSpeed(speed);
    await preferences.setSpeed(speed);
  }

  /// off -> all -> one -> off
  Future<void> cycleLoopMode() async {
    final next = switch (player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };

    await player.setLoopMode(next);
    await preferences.setLoopMode(next);
  }

  Future<void> toggleShuffle() async {
    final enable = !player.shuffleModeEnabled;

    if (enable) {
      await player.shuffle();
    }

    await player.setShuffleModeEnabled(enable);
    await preferences.setShuffle(enable);
  }

  // ---------------------------------------------------------------------------
  // Sleep timer
  // ---------------------------------------------------------------------------

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();

    var remaining = duration;
    sleepTimer.value = SleepTimerState.timed(remaining);

    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining -= const Duration(seconds: 1);

      if (remaining <= Duration.zero) {
        unawaited(player.pause());
        cancelSleepTimer();
      } else {
        sleepTimer.value = SleepTimerState.timed(remaining);
      }
    });
  }

  void startEndOfSurahTimer() {
    cancelSleepTimer();
    _endOfSurahArmed = true;
    sleepTimer.value = const SleepTimerState.endOfSurah();
  }

  void cancelSleepTimer() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _endOfSurahArmed = false;
    sleepTimer.value = null;
  }

  Future<void> dispose() async {
    if (_listening) {
      await _saveProgress();
    }

    cancelSleepTimer();

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    _subscriptions.clear();

    await _errors.close();
    hasSession.dispose();
    sleepTimer.dispose();
    await player.dispose();
  }
}