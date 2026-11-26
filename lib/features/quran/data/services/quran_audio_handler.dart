import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/surah.dart';
import 'quran_audio_service.dart';

/// Drives the system media notification (notification shade + lock screen).
///
/// Buttons, in this exact order:
///   favorite  |  previous  |  play / pause  |  next  |  close (X)
///
/// It owns no playback logic: every command is forwarded to
/// [QuranAudioService], so the app UI and the notification always behave the
/// same and the "resume where I stopped" logic is shared.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  QuranAudioHandler({
    required this.audio,
    required this.surahs,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.artworkUri,
    Listenable? favoritesListenable,
  }) : _favoritesListenable = favoritesListenable {
    _subscriptions.addAll([
      _player.playbackEventStream.listen((_) => _broadcast()),
      _player.currentIndexStream.listen(_onIndexChanged),
      _player.durationStream.listen(_onDurationChanged),
    ]);

    // Keep the heart in sync when a favorite is toggled inside the app.
    _favoritesListenable?.addListener(_broadcast);
  }

  static const String _favoriteAction = 'toggle_favorite';
  static const String _closeAction = 'close';

  static const String _artist = 'مشاري بن راشد العفاسي';
  static const String _album = 'القرآن الكريم';

  final QuranAudioService audio;
  final List<Surah> surahs;
  final bool Function(int surahNumber) isFavorite;
  final Future<void> Function(int surahNumber) onToggleFavorite;
  final Uri? artworkUri;

  final Listenable? _favoritesListenable;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// True after the user pressed the X: the notification stays hidden until
  /// playback starts again.
  bool _closed = false;

  AudioPlayer get _player => audio.player;

  // ---------------------------------------------------------------------------
  // Metadata
  // ---------------------------------------------------------------------------

  MediaItem _buildItem(int index, Duration? duration) {
    final surah = surahs[index];

    return MediaItem(
      id: surah.number.toString(),
      title: 'سورة ${surah.arabicName}',
      artist: _artist,
      album: _album,
      duration: duration,
      artUri: artworkUri,
    );
  }

  void _onIndexChanged(int? index) {
    if (index == null || index < 0 || index >= surahs.length) return;

    mediaItem.add(_buildItem(index, _player.duration));
    _broadcast();
  }

  void _onDurationChanged(Duration? duration) {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= surahs.length) return;

    mediaItem.add(_buildItem(index, duration));
  }

  // ---------------------------------------------------------------------------
  // Playback state -> notification
  // ---------------------------------------------------------------------------

  static const Map<ProcessingState, AudioProcessingState> _processingStates = {
    ProcessingState.idle: AudioProcessingState.idle,
    ProcessingState.loading: AudioProcessingState.loading,
    ProcessingState.buffering: AudioProcessingState.buffering,
    ProcessingState.ready: AudioProcessingState.ready,
    ProcessingState.completed: AudioProcessingState.completed,
  };

  void _broadcast() {
    final playing = _player.playing;

    if (playing) _closed = false;

    // Hidden while the app only shows the restored session (nothing played
    // yet) and after the user pressed the X, until playback starts again.
    if (_closed || !audio.hasInteracted) {
      playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      return;
    }

    final index = _player.currentIndex;
    final favorite =
        index != null && index >= 0 && index < surahs.length
            ? isFavorite(surahs[index].number)
            : false;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.custom(
            androidIcon: favorite
                ? 'drawable/ic_notif_fav_on'
                : 'drawable/ic_notif_fav_off',
            label: favorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            name: _favoriteAction,
          ),
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: 'drawable/ic_notif_close',
            label: 'إغلاق',
            name: _closeAction,
          ),
        ],
        // Collapsed notification (Android < 13): previous, play/pause, next.
        androidCompactActionIndices: const [1, 2, 3],
        systemActions: const {
          MediaAction.seek,
          MediaAction.skipToPrevious,
          MediaAction.skipToNext,
          MediaAction.play,
          MediaAction.pause,
        },
        processingState: _processingStates[_player.processingState] ??
            AudioProcessingState.idle,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: index,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Commands coming from the notification / lock screen / headset
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() {
    _closed = false;
    return audio.play();
  }

  @override
  Future<void> pause() => audio.pause();

  @override
  Future<void> skipToNext() => audio.next();

  @override
  Future<void> skipToPrevious() => audio.previous();

  @override
  Future<void> seek(Duration position) => audio.seek(position);

  /// Also called when the user swipes the notification away.
  @override
  Future<void> stop() async {
    _closed = true;

    await audio.pause();
    await audio.persistNow();

    _broadcast();
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case _favoriteAction:
        final index = _player.currentIndex;
        if (index != null && index >= 0 && index < surahs.length) {
          await onToggleFavorite(surahs[index].number);
        }
        return null;

      case _closeAction:
        await stop();
        return null;
    }

    return super.customAction(name, extras);
  }

  Future<void> dispose() async {
    _favoritesListenable?.removeListener(_broadcast);

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }

    _subscriptions.clear();
  }
}