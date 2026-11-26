import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../data/services/quran_audio_service.dart';
import '../../domain/entities/surah.dart';
import '../state/quran_controller.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.audioService,
    required this.surahs,
    required this.controller,
  });

  final QuranAudioService audioService;
  final List<Surah> surahs;
  final QuranController controller;

  /// Slides the player up from the bottom, like a music app.
  static Future<void> open(
    BuildContext context, {
    required QuranAudioService audioService,
    required List<Surah> surahs,
    required QuranController controller,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => PlayerPage(
          audioService: audioService,
          surahs: surahs,
          controller: controller,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final tween = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));

          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  QuranAudioService get _audio => widget.audioService;
  AudioPlayer get _player => widget.audioService.player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: _player.currentIndexStream,
      initialData: _player.currentIndex,
      builder: (context, snapshot) {
        final index =
            (snapshot.data ?? 0).clamp(0, widget.surahs.length - 1).toInt();
        final surah = widget.surahs[index];

        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final colors = context.colors;
            final isFavorite = widget.controller.isFavorite(surah.number);

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'إغلاق',
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: const Text('يتم التشغيل الآن'),
                actions: [
                  IconButton(
                    tooltip:
                        isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? colors.gold : null,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.controller.toggleFavorite(surah.number);
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final artworkSize = math
                        .min(constraints.maxWidth * 0.64,
                            constraints.maxHeight * 0.34)
                        .clamp(150.0, 280.0)
                        .toDouble();

                    // Scrollable so small phones / large fonts never overflow.
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 16),
                            _Artwork(
                              size: artworkSize,
                              surahNumber: surah.number,
                              player: _player,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              surah.arabicName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: colors.goldText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              surah.englishName,
                              style: TextStyle(
                                fontSize: 16,
                                color: colors.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'السورة رقم ${ArabicUtils.toArabicDigits(surah.number)}',
                              style: TextStyle(
                                color: colors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _ProgressBar(player: _player),
                            const SizedBox(height: 8),
                            _MainControls(audioService: _audio),
                            const SizedBox(height: 20),
                            _SecondaryControls(audioService: _audio),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Artwork
// -----------------------------------------------------------------------------

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.size,
    required this.surahNumber,
    required this.player,
  });

  final double size;
  final int surahNumber;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inner = size * 0.855;

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      initialData: player.playerState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final busy = playing &&
            (state?.processingState == ProcessingState.loading ||
                state?.processingState == ProcessingState.buffering);

        return AnimatedScale(
          scale: playing ? 1.0 : 0.94,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.artworkStart, colors.artworkEnd],
              ),
              border: Border.all(color: colors.gold, width: 3),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: inner,
                  height: inner,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.gold, width: 1.5),
                  ),
                ),
                if (busy)
                  SizedBox(
                    width: inner,
                    height: inner,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colors.gold,
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'القرآن الكريم',
                      style: TextStyle(
                        fontSize: size * 0.104,
                        fontWeight: FontWeight.bold,
                        color: colors.goldText,
                      ),
                    ),
                    SizedBox(height: size * 0.04),
                    Text(
                      ArabicUtils.toArabicDigits(surahNumber),
                      style: TextStyle(
                        fontSize: size * 0.075,
                        color: colors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Progress bar (smooth dragging, no jitter while scrubbing)
// -----------------------------------------------------------------------------

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.player});

  final AudioPlayer player;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = widget.player;

    // Timelines are LTR by media convention, even in an RTL app.
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
              final position = positionSnapshot.data ?? player.position;

              final maxMs = duration.inMilliseconds.toDouble();
              final ready = maxMs > 0;

              final positionMs = position.inMilliseconds.toDouble();
              final shownMs = _dragValue ?? positionMs;

              final sliderValue = ready
                  ? shownMs.clamp(0.0, maxMs).toDouble()
                  : 0.0;

              return Column(
                children: [
                  Slider(
                    min: 0,
                    max: ready ? maxMs : 1,
                    value: sliderValue,
                    onChanged: ready
                        ? (value) => setState(() => _dragValue = value)
                        : null,
                    onChangeEnd: (value) {
                      player.seek(Duration(milliseconds: value.round()));
                      setState(() => _dragValue = null);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ArabicUtils.formatDuration(
                            Duration(milliseconds: shownMs.round()),
                          ),
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                        Text(
                          ArabicUtils.formatDuration(duration),
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Main transport controls
// -----------------------------------------------------------------------------

class _MainControls extends StatelessWidget {
  const _MainControls({required this.audioService});

  final QuranAudioService audioService;

  @override
  Widget build(BuildContext context) {
    // Previous / next arrows must point the universal way, so LTR here.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'السورة السابقة',
            iconSize: 36,
            onPressed: audioService.previous,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          _SkipButton(
            forward: false,
            tooltip: 'رجوع ١٥ ثانية',
            onPressed: audioService.rewind15,
          ),
          const SizedBox(width: 8),
          _PlayButton(audioService: audioService),
          const SizedBox(width: 8),
          _SkipButton(
            forward: true,
            tooltip: 'تقديم ١٥ ثانية',
            onPressed: audioService.forward15,
          ),
          IconButton(
            tooltip: 'السورة التالية',
            iconSize: 36,
            onPressed: audioService.next,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}

/// A 15-second skip button. The built-in "10" icons were misleading because
/// the app skips 15 seconds.
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.forward,
    required this.tooltip,
    required this.onPressed,
  });

  final bool forward;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.replay, size: 36, color: IconTheme.of(context).color);

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 36,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          forward ? Transform.flip(flipX: true, child: icon) : icon,
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              '15',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.audioService});

  final QuranAudioService audioService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = audioService.player;

    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      initialData: player.playerState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final loading = playing &&
            (state?.processingState == ProcessingState.loading ||
                state?.processingState == ProcessingState.buffering);

        return Semantics(
          button: true,
          label: playing ? 'إيقاف مؤقت' : 'تشغيل',
          child: Material(
            color: colors.gold,
            elevation: 4,
            shadowColor: colors.shadow,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: audioService.togglePlayPause,
              child: SizedBox(
                width: 76,
                height: 76,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: loading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: colors.onGold,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(playing),
                            color: colors.onGold,
                            size: 42,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Secondary controls: shuffle, repeat, speed, volume, sleep timer
// -----------------------------------------------------------------------------

class _SecondaryControls extends StatelessWidget {
  const _SecondaryControls({required this.audioService});

  final QuranAudioService audioService;

  static String _speedLabel(double speed) {
    return '${speed == speed.roundToDouble() ? speed.toInt() : speed}x';
  }

  @override
  Widget build(BuildContext context) {
    final player = audioService.player;
    final colors = context.colors;

    return Row(
      children: [
        StreamBuilder<bool>(
          stream: player.shuffleModeEnabledStream,
          initialData: player.shuffleModeEnabled,
          builder: (context, snapshot) {
            final on = snapshot.data ?? false;

            return _ToolButton(
              icon: Icons.shuffle_rounded,
              label: 'عشوائي',
              active: on,
              onTap: audioService.toggleShuffle,
            );
          },
        ),
        StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          initialData: player.loopMode,
          builder: (context, snapshot) {
            final mode = snapshot.data ?? LoopMode.off;

            return _ToolButton(
              icon: mode == LoopMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              label: switch (mode) {
                LoopMode.off => 'تكرار',
                LoopMode.all => 'كل السور',
                LoopMode.one => 'هذه السورة',
              },
              active: mode != LoopMode.off,
              onTap: audioService.cycleLoopMode,
            );
          },
        ),
        StreamBuilder<double>(
          stream: player.speedStream,
          initialData: player.speed,
          builder: (context, snapshot) {
            final speed = snapshot.data ?? 1.0;

            return _ToolButton(
              text: _speedLabel(speed),
              label: 'السرعة',
              active: speed != 1.0,
              onTap: () => _showSheet(
                context,
                _SpeedSheet(audioService: audioService),
              ),
            );
          },
        ),
        _ToolButton(
          icon: Icons.volume_up_rounded,
          label: 'الصوت',
          onTap: () => _showSheet(
            context,
            _VolumeSheet(player: player),
          ),
        ),
        ValueListenableBuilder<SleepTimerState?>(
          valueListenable: audioService.sleepTimer,
          builder: (context, state, _) {
            final label = state == null
                ? 'المؤقت'
                : (state.endOfSurah
                    ? 'آخر السورة'
                    : ArabicUtils.formatDuration(state.remaining!));

            return _ToolButton(
              icon: state == null
                  ? Icons.bedtime_outlined
                  : Icons.bedtime_rounded,
              label: label,
              active: state != null,
              activeColor: colors.gold,
              onTap: () => _showSheet(
                context,
                _SleepSheet(audioService: audioService),
              ),
            );
          },
        ),
      ],
    );
  }

  static void _showSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(child: sheet),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    this.icon,
    this.text,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
  }) : assert(icon != null || text != null);

  final IconData? icon;
  final String? text;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? (activeColor ?? colors.gold) : colors.muted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 26,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: color, size: 24)
                      : Text(
                          text!,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Bottom sheets
// -----------------------------------------------------------------------------

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.audioService});

  final QuranAudioService audioService;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final player = audioService.player;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'سرعة التشغيل',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          StreamBuilder<double>(
            stream: player.speedStream,
            initialData: player.speed,
            builder: (context, snapshot) {
              final current = snapshot.data ?? 1.0;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final speed in _speeds)
                    ChoiceChip(
                      label: Text(_SecondaryControls._speedLabel(speed)),
                      selected: current == speed,
                      showCheckmark: false,
                      onSelected: (_) {
                        audioService.setSpeed(speed);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VolumeSheet extends StatelessWidget {
  const _VolumeSheet({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: player.volumeStream,
      initialData: player.volume,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? 1.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مستوى الصوت',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    Icon(
                      volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_down_rounded,
                    ),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 1,
                        value: volume.clamp(0.0, 1.0).toDouble(),
                        onChanged: player.setVolume,
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SleepSheet extends StatelessWidget {
  const _SleepSheet({required this.audioService});

  final QuranAudioService audioService;

  static const _minutes = [15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ValueListenableBuilder<SleepTimerState?>(
      valueListenable: audioService.sleepTimer,
      builder: (context, state, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'مؤقت النوم',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final minutes in _minutes)
                ListTile(
                  leading: Icon(Icons.timer_outlined, color: colors.gold),
                  title: Text('${ArabicUtils.toArabicDigits(minutes)} دقيقة'),
                  onTap: () {
                    audioService.startSleepTimer(Duration(minutes: minutes));
                    Navigator.of(context).pop();
                  },
                ),
              ListTile(
                leading: Icon(Icons.menu_book_outlined, color: colors.gold),
                title: const Text('حتى نهاية السورة'),
                onTap: () {
                  audioService.startEndOfSurahTimer();
                  Navigator.of(context).pop();
                },
              ),
              if (state != null)
                ListTile(
                  leading: Icon(Icons.timer_off_outlined, color: colors.goldText),
                  title: Text(
                    'إلغاء المؤقت',
                    style: TextStyle(
                      color: colors.goldText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    audioService.cancelSleepTimer();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}