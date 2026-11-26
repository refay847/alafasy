import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/surah.dart';

class QuranAudioService {
  QuranAudioService({
    required this.surahs,
  });

  final List<Surah> surahs;

  final AudioPlayer player = AudioPlayer();

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

    await player.setAudioSources(
      sources,
      preload: false,
    );
  }

  Future<void> playSurah(int index) async {
    if (index < 0 || index >= surahs.length) {
      return;
    }

    if (player.currentIndex != index) {
      await player.seek(
        Duration.zero,
        index: index,
      );
    }

    await player.play();
  }

  Future<void> play() {
    return player.play();
  }

  Future<void> pause() {
    return player.pause();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
    }
  }

  Future<void> previous() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    }
  }

  Future<void> seek(Duration position) {
    return player.seek(position);
  }

  Future<void> forward15() async {
    final position = player.position;
    final duration = player.duration;

    if (duration == null) return;

    final newPosition = position + const Duration(seconds: 15);

    await player.seek(
      newPosition > duration ? duration : newPosition,
    );
  }

  Future<void> rewind15() async {
    final position = player.position;

    final newPosition = position - const Duration(seconds: 15);

    await player.seek(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }

  Future<void> setVolume(double volume) {
    return player.setVolume(volume);
  }

  Future<void> setSpeed(double speed) {
    return player.setSpeed(speed);
  }

  Future<void> dispose() async {
    await player.dispose();
  }
}
