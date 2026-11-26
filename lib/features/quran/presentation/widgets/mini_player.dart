import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/services/quran_audio_service.dart';
import '../../domain/entities/surah.dart';
import '../pages/player_page.dart';
import '../state/quran_controller.dart';
import 'equalizer_icon.dart';

/// Compact now-playing bar. Appears once something has been played (or a
/// previous session was restored) and opens the full player on tap.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.audioService,
    required this.surahs,
    required this.controller,
  });

  final QuranAudioService audioService;
  final List<Surah> surahs;
  final QuranController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: audioService.hasSession,
      builder: (context, active, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: active
              ? _MiniPlayerCard(
                  audioService: audioService,
                  surahs: surahs,
                  controller: controller,
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

class _MiniPlayerCard extends StatelessWidget {
  const _MiniPlayerCard({
    required this.audioService,
    required this.surahs,
    required this.controller,
  });

  final QuranAudioService audioService;
  final List<Surah> surahs;
  final QuranController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = audioService.player;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: StreamBuilder<int?>(
          stream: player.currentIndexStream,
          initialData: player.currentIndex,
          builder: (context, snapshot) {
            final index =
                (snapshot.data ?? 0).clamp(0, surahs.length - 1).toInt();
            final surah = surahs[index];

            return Material(
              color: colors.card,
              elevation: 6,
              shadowColor: colors.shadow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colors.border),
              ),
              child: InkWell(
                onTap: () => PlayerPage.open(
                  context,
                  audioService: audioService,
                  surahs: surahs,
                  controller: controller,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                      child: Row(
                        children: [
                          _Badge(player: audioService.player),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  surah.arabicName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  surah.englishName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Transport icons keep the universal LTR convention.
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PlayPauseButton(audioService: audioService),
                                IconButton(
                                  tooltip: 'التالي',
                                  onPressed: audioService.next,
                                  icon: const Icon(Icons.skip_next_rounded),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MiniProgress(player: player),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.goldSoft,
        border: Border.all(color: colors.gold),
      ),
      child: Center(
        child: StreamBuilder<bool>(
          stream: player.playingStream,
          initialData: player.playing,
          builder: (context, snapshot) {
            return EqualizerIcon(
              animating: snapshot.data ?? false,
              color: colors.gold,
              size: 20,
            );
          },
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.audioService});

  final QuranAudioService audioService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = audioService.player;

    return StreamBuilder<bool>(
      stream: player.playingStream,
      initialData: player.playing,
      builder: (context, snapshot) {
        final playing = snapshot.data ?? false;

        return Material(
          color: colors.gold,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: audioService.togglePlayPause,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: colors.onGold,
                size: 26,
                semanticLabel: playing ? 'إيقاف مؤقت' : 'تشغيل',
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: StreamBuilder<Duration?>(
        stream: player.durationStream,
        initialData: player.duration,
        builder: (context, durationSnapshot) {
          final duration = durationSnapshot.data ?? Duration.zero;

          return StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;

              final ratio = duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds)
                      .clamp(0.0, 1.0)
                      .toDouble()
                  : 0.0;

              return LinearProgressIndicator(
                value: ratio,
                minHeight: 3,
                color: colors.gold,
                backgroundColor: colors.border,
              );
            },
          );
        },
      ),
    );
  }
}