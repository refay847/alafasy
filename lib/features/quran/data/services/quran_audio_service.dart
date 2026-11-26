import 'dart:async';

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

  /// The surah index that is currently stored in preferences (-1 = nothing).
  int _persistedIndex = -1;

  /// False until the user (or the notification controls) actually does
  /// something. While false, the player is only showing the *restored* state,
  /// so no event coming from the player may overwrite the saved session.
  bool _interacted = false;

  /// True once the user (or the notification) has started interacting.
  bool get hasInteracted => _interacted;

  /// The restored surah + position that must be applied with an explicit seek
  /// the first time playback starts (see [_applyPendingRestore]).
  ({int index, Duration position})? _pendingRestore;

  Future<void> initialize() async {
    final sources =
        surahs.map((surah) => AudioSource.asset(surah.audioAsset)).toList();

    final hasLastSession = preferences.hasLastSession;
    final savedIndex = hasLastSession
        ? preferences.lastIndex.clamp(0, surahs.length - 1).toInt()
        : 0;
    final savedPosition = hasLastSession
        ? Duration(milliseconds: preferences.lastPositionMs)
        : Duration.zero;

    _persistedIndex = hasLastSession ? savedIndex : -1;

    // Until the user interacts, nothing may overwrite the saved session.
    if (!player.playing) _interacted = false;

    Future<void> load({required bool preload}) {
      return player.setAudioSources(
        sources,
        preload: preload,
        initialIndex: savedIndex,
        initialPosition: savedPosition,
      );
    }

    // Load the saved surah right away (preload: true). With lazy loading the
    // UI showed the restored surah, but the native player was not yet told
    // which track to open, so the first "play" could start from surah 1.
    try {
      await load(preload: true);
    } catch (_) {
      // e.g. the saved asset failed to open: don't block the whole app.
      await load(preload: false);
    }

    // Belt and braces: apply the restored surah + position explicitly on the
    // first play, whichever button triggers it.
    _pendingRestore =
        hasLastSession ? (index: savedIndex, position: savedPosition) : null;

    if (player.currentIndex != savedIndex) {
      await player.seek(savedPosition, index: savedIndex);
    }

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
      player.playingStream.listen((playing) {
        if (playing) {
          // Playing (from the app or the notification) means the restored
          // state is no longer "pristine".
          _interacted = true;
        } else {
          unawaited(persistNow());
        }
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

    // While the user has not interacted, the player is only mirroring the
    // restored session. Ignore it, otherwise a transient index 0 emitted
    // during loading would overwrite the surah we want to resume.
    if (!_interacted) return;

    if (index != _persistedIndex) {
      _persistedIndex = index;
      unawaited(preferences.saveSession(index: index, positionMs: 0));
    }
  }

  void _onPosition(Duration position) {
    // Persist progress at most every 5 seconds while playing.
    final now = DateTime.now();
    if (_interacted &&
        player.playing &&
        player.currentIndex == _persistedIndex &&
        now.difference(_lastSave) >= const Duration(seconds: 5)) {
      _lastSave = now;
      unawaited(
        preferences.saveSession(
          index: _persistedIndex,
          positionMs: position.inMilliseconds,
        ),
      );
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

  /// Writes the current surah + position right now. Called on pause, when the
  /// app goes to the background, and on dispose, because Android can kill the
  /// process without any further notice.
  Future<void> persistNow() async {
    if (!_interacted) return;

    final index = player.currentIndex;
    if (index == null) return;

    _persistedIndex = index;

    await preferences.saveSession(
      index: index,
      positionMs: player.position.inMilliseconds,
    );
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Seeks to the restored surah + position. Runs once, right before the first
  /// playback after startup.
  Future<void> _applyPendingRestore() async {
    final restore = _pendingRestore;
    if (restore == null) return;

    _pendingRestore = null;
    await player.seek(restore.position, index: restore.index);
  }

  Future<void> playSurah(int index) async {
    if (index < 0 || index >= surahs.length) return;

    _interacted = true;
    hasSession.value = true;

    final isDifferent = player.currentIndex != index;

    // Always store the session (also for surah #1, which used to be skipped
    // because its index equals the player's initial index).
    _persistedIndex = index;
    await preferences.saveSession(
      index: index,
      positionMs: isDifferent
          ? 0
          : (_pendingRestore?.position.inMilliseconds ??
              player.position.inMilliseconds),
    );

    if (isDifferent) {
      // Explicitly choosing another surah replaces the restored one.
      _pendingRestore = null;
      await player.seek(Duration.zero, index: index);
    } else {
      // Same surah as the restored one: continue from the saved minute.
      await _applyPendingRestore();

      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
    }

    // Do NOT await play(): its Future only completes when playback pauses
    // or finishes, which would block the caller for the whole surah.
    if (!player.playing) {
      unawaited(player.play());
    }
  }

  /// Starts / resumes playback. Used by the in-app buttons and by the
  /// notification, so both behave exactly the same.
  Future<void> play() async {
    _interacted = true;
    hasSession.value = true;

    if (player.playing) return;

    await _applyPendingRestore();

    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }

    unawaited(player.play());
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      _interacted = true;
      await player.pause();
      return;
    }

    await play();
  }

  Future<void> pause() => player.pause();

  Future<void> next() async {
    _interacted = true;
    await _applyPendingRestore();

    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> previous() async {
    _interacted = true;
    await _applyPendingRestore();

    // just_audio restarts the current track if more than 3s have played.
    await player.seekToPrevious();
  }

  Future<void> seek(Duration position) async {
    _interacted = true;
    _pendingRestore = null;
    await player.seek(position);
  }

  Future<void> forward15() async {
    final duration = player.duration;
    if (duration == null) return;

    _interacted = true;
    await _applyPendingRestore();

    final target = player.position + const Duration(seconds: 15);
    await player.seek(target > duration ? duration : target);
  }

  Future<void> rewind15() async {
    _interacted = true;
    await _applyPendingRestore();

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
      await persistNow();
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