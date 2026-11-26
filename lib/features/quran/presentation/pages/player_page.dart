import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/services/quran_audio_service.dart';
import '../../domain/entities/surah.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.audioService,
    required this.surahs,
  });

  final QuranAudioService audioService;
  final List<Surah> surahs;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  double speed = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF5),

      appBar: AppBar(
        title: const Text('المشغل'),
      ),

      body: StreamBuilder<int?>(
        stream: widget.audioService.player.currentIndexStream,
        builder: (context, snapshot) {
          final index = snapshot.data ??
              widget.audioService.player.currentIndex ??
              0;

          final surah = widget.surahs[index];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Spacer(),

                  _Artwork(
                    surahNumber: surah.number,
                  ),

                  const SizedBox(height: 28),

                  Text(
                    surah.arabicName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7C5E20),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    surah.englishName,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'السورة رقم ${surah.number}',
                    style: const TextStyle(
                      color: Color(0xFFC49A3A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 30),

                  _ProgressBar(
                    player: widget.audioService.player,
                  ),

                  const SizedBox(height: 16),

                  _MainControls(
                    player: widget.audioService.player,
                    onPrevious: widget.audioService.previous,
                    onNext: widget.audioService.next,
                    onRewind: widget.audioService.rewind15,
                    onForward: widget.audioService.forward15,
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _SpeedButton(
                        speed: speed,
                        onChanged: (value) async {
                          setState(() {
                            speed = value;
                          });

                          await widget.audioService.setSpeed(value);
                        },
                      ),

                      IconButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) {
                              return _VolumeSheet(
                                player: widget.audioService.player,
                              );
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.volume_up_outlined,
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          setState(() {
                            widget.audioService.player.setLoopMode(
                              widget.audioService.player.loopMode ==
                                      LoopMode.one
                                  ? LoopMode.off
                                  : LoopMode.one,
                            );
                          });
                        },
                        icon: StreamBuilder<LoopMode>(
                          stream:
                              widget.audioService.player.loopModeStream,
                          builder: (context, snapshot) {
                            final loopMode = snapshot.data;

                            return Icon(
                              Icons.repeat_one,
                              color: loopMode == LoopMode.one
                                  ? const Color(0xFFC49A3A)
                                  : Colors.grey,
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.surahNumber,
  });

  final int surahNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8E5),
            Color(0xFFE8D29A),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFC49A3A),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 205,
            height: 205,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFC49A3A),
                width: 1.5,
              ),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'القرآن الكريم',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF76561A),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                '$surahNumber',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFFC49A3A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.player,
  });

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;

            final max = duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;

            final value = position.inMilliseconds
                .clamp(0, duration.inMilliseconds)
                .toDouble();

            return Column(
              children: [
                Slider(
                  min: 0,
                  max: max,
                  value: value,
                  onChanged: duration == Duration.zero
                      ? null
                      : (value) {
                          player.seek(
                            Duration(
                              milliseconds: value.round(),
                            ),
                          );
                        },
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(position)),
                      Text(_format(duration)),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls({
    required this.player,
    required this.onPrevious,
    required this.onNext,
    required this.onRewind,
    required this.onForward,
  });

  final AudioPlayer player;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRewind;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onPrevious,
          iconSize: 32,
          icon: const Icon(
            Icons.skip_previous_rounded,
          ),
        ),

        IconButton(
          onPressed: onRewind,
          iconSize: 34,
          icon: const Icon(
            Icons.replay_10_rounded,
          ),
        ),

        const SizedBox(width: 8),

        StreamBuilder<bool>(
          stream: player.playingStream,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;

            return Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFC49A3A),
              ),
              child: IconButton(
                onPressed: () {
                  playing ? player.pause() : player.play();
                },
                icon: Icon(
                  playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 8),

        IconButton(
          onPressed: onForward,
          iconSize: 34,
          icon: const Icon(
            Icons.forward_10_rounded,
          ),
        ),

        IconButton(
          onPressed: onNext,
          iconSize: 32,
          icon: const Icon(
            Icons.skip_next_rounded,
          ),
        ),
      ],
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({
    required this.speed,
    required this.onChanged,
  });

  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: speed,
      onSelected: onChanged,
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: 0.75,
            child: Text('0.75x'),
          ),
          PopupMenuItem(
            value: 1.0,
            child: Text('1.0x'),
          ),
          PopupMenuItem(
            value: 1.25,
            child: Text('1.25x'),
          ),
          PopupMenuItem(
            value: 1.5,
            child: Text('1.5x'),
          ),
          PopupMenuItem(
            value: 2.0,
            child: Text('2.0x'),
          ),
        ];
      },
      child: Text(
        '${speed}x',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF8A6A24),
        ),
      ),
    );
  }
}

class _VolumeSheet extends StatelessWidget {
  const _VolumeSheet({
    required this.player,
  });

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.volumeStream,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 1.0;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مستوى الصوت',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Slider(
                min: 0,
                max: 1,
                value: volume,
                onChanged: player.setVolume,
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}