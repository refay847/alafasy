import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../../../core/widgets/app_logo.dart';
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
                    // Outer size of the artwork + progress ring.
                    final ringSize = math
                        .min(constraints.maxWidth - 48,
                            constraints.maxHeight * 0.42)
                        .clamp(230.0, 330.0)
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
                            const SizedBox(height: 8),
                            Text(
                              surah.arabicName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: colors.goldText,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _ArtworkProgress(
                              size: ringSize,
                              surahNumber: surah.number,
                              player: _player,
                            ),
                            const SizedBox(height: 20),
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
                // The reciter photo fills the inner circle.
                SizedBox(
                  width: inner,
                  height: inner,
                  child: ClipOval(
                    child: Image.asset(
                      AppLogo.photoAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.high,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colors.goldSoft,
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: colors.gold,
                          size: size * 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thin gold ring around the photo.
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
                // Surah number badge.
                Positioned(
                  bottom: size * 0.01,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: size * 0.19,
                      minHeight: size * 0.19,
                    ),
                    padding: EdgeInsets.symmetric(horizontal: size * 0.04),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(size),
                      color: colors.gold,
                      border: Border.all(color: colors.card, width: 2.5),
                    ),
                    child: Text(
                      ArabicUtils.toArabicDigits(surahNumber),
                      style: TextStyle(
                        fontSize: size * 0.075,
                        fontWeight: FontWeight.bold,
                        color: colors.onGold,
                      ),
                    ),
                  ),
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
// Artwork wrapped by a circular progress ring (with a gap at the top that
// shows "elapsed / total")
// -----------------------------------------------------------------------------

/// Formats a duration as `mm:ss` (or `h:mm:ss` for long recordings) using
/// Latin digits, e.g. `08:57`.
String _clock(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class _ArtworkProgress extends StatefulWidget {
  const _ArtworkProgress({
    required this.size,
    required this.surahNumber,
    required this.player,
  });

  /// Outer size of the whole widget (ring included).
  final double size;
  final int surahNumber;
  final AudioPlayer player;

  @override
  State<_ArtworkProgress> createState() => _ArtworkProgressState();
}

class _ArtworkProgressState extends State<_ArtworkProgress> {
  /// Distance between the widget edge and the centre line of the ring.
  static const double _inset = 16;
  static const double _strokeWidth = 6;
  static const double _thumbRadius = 9;

  /// Angular size of the opening at the top of the ring.
  static const double _gap = 72 * math.pi / 180;
  static const double _sweep = 2 * math.pi - _gap;

  /// How far from the ring line a touch still counts as grabbing the ring.
  static const double _touchBand = 26;

  /// 0..1 while the user is scrubbing, otherwise null.
  double? _dragFraction;
  Duration _duration = Duration.zero;

  double get _radius => widget.size / 2 - _inset;
  bool get _ready => _duration.inMilliseconds > 0;

  bool _hitsRing(Offset local) {
    if (!_ready) return false;

    final distance = (local - Offset(widget.size / 2, widget.size / 2)).distance;

    return (distance - _radius).abs() <= _touchBand;
  }

  /// Converts a touch position to a 0..1 progress value.
  double _fractionAt(Offset local, double previous) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = local - center;

    // Angle measured counter-clockwise from 12 o'clock (the ring fills from
    // the left side of the opening, down and around to the right).
    var angle = math.atan2(-delta.dx, -delta.dy);
    if (angle < 0) angle += 2 * math.pi;

    const half = _gap / 2;

    // Inside the opening: stick to whichever end we were closest to, so the
    // thumb never jumps from the end to the start while dragging.
    if (angle < half || angle > 2 * math.pi - half) {
      return previous >= 0.5 ? 1.0 : 0.0;
    }

    return ((angle - half) / _sweep).clamp(0.0, 1.0).toDouble();
  }

  void _onStart(Offset local, double current) {
    HapticFeedback.selectionClick();
    setState(() => _dragFraction = _fractionAt(local, current));
  }

  void _onUpdate(Offset local) {
    setState(
      () => _dragFraction = _fractionAt(local, _dragFraction ?? 0),
    );
  }

  void _onEnd() {
    final fraction = _dragFraction;
    if (fraction == null) return;

    final target = Duration(
      milliseconds: (fraction * _duration.inMilliseconds).round(),
    );

    // Keep showing the dragged value until the seek has finished, otherwise
    // the thumb flickers back to the old position for a frame.
    widget.player.seek(target).whenComplete(() {
      if (mounted) setState(() => _dragFraction = null);
    });
  }

  void _onCancel() {
    if (mounted) setState(() => _dragFraction = null);
  }

  void _nudge(Duration delta) {
    if (!_ready) return;

    final target = widget.player.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);

    widget.player.seek(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final player = widget.player;
    final artworkSize = widget.size - 2 * (_inset + 22);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The photo does not depend on the position stream, so it is never
          // rebuilt while the song plays.
          _Artwork(
            size: artworkSize,
            surahNumber: widget.surahNumber,
            player: player,
          ),

          // Ring + time label + gestures.
          Directionality(
            textDirection: TextDirection.ltr,
            child: StreamBuilder<Duration?>(
              stream: player.durationStream,
              initialData: player.duration,
              builder: (context, durationSnapshot) {
                _duration = durationSnapshot.data ?? Duration.zero;

                return StreamBuilder<Duration>(
                  stream: player.positionStream,
                  initialData: player.position,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final totalMs = _duration.inMilliseconds;

                    final playedFraction = _ready
                        ? (position.inMilliseconds / totalMs)
                            .clamp(0.0, 1.0)
                            .toDouble()
                        : 0.0;
                    final fraction = _dragFraction ?? playedFraction;

                    final shownPosition = _dragFraction != null
                        ? Duration(
                            milliseconds: (fraction * totalMs).round(),
                          )
                        : position;

                    final label = _ready
                        ? '${_clock(shownPosition)} / ${_clock(_duration)}'
                        : '--:-- / --:--';

                    return Semantics(
                      slider: true,
                      label: 'التقدم',
                      value: label,
                      onIncrease: () => _nudge(const Duration(seconds: 15)),
                      onDecrease: () => _nudge(const Duration(seconds: -15)),
                      child: RawGestureDetector(
                        behavior: HitTestBehavior.opaque,
                        gestures: {
                          _RingGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                  _RingGestureRecognizer>(
                            () => _RingGestureRecognizer(),
                            (recognizer) {
                              recognizer.hitTest = _hitsRing;
                              recognizer.onStart = (local) {
                                _onStart(local, fraction);
                              };
                              recognizer.onUpdate = _onUpdate;
                              recognizer.onEnd = _onEnd;
                              recognizer.onCancel = _onCancel;
                            },
                          ),
                        },
                        child: SizedBox(
                          width: widget.size,
                          height: widget.size,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _RingPainter(
                                    fraction: fraction,
                                    inset: _inset,
                                    gap: _gap,
                                    strokeWidth: _strokeWidth,
                                    thumbRadius: _thumbRadius,
                                    dragging: _dragFraction != null,
                                    trackColor:
                                        colors.gold.withValues(alpha: 0.22),
                                    progressColor: colors.gold,
                                    thumbBorderColor: colors.card,
                                  ),
                                ),
                              ),
                              // Time sits in the opening at the top.
                              Positioned(
                                top: _inset - 14,
                                left: 0,
                                right: 0,
                                height: 28,
                                child: Center(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                      color: _dragFraction != null
                                          ? colors.goldText
                                          : colors.muted,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.inset,
    required this.gap,
    required this.strokeWidth,
    required this.thumbRadius,
    required this.dragging,
    required this.trackColor,
    required this.progressColor,
    required this.thumbBorderColor,
  });

  final double fraction;
  final double inset;
  final double gap;
  final double strokeWidth;
  final double thumbRadius;
  final bool dragging;
  final Color trackColor;
  final Color progressColor;
  final Color thumbBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - inset;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 0 rad is 3 o'clock. Start just left of 12 o'clock and sweep
    // counter-clockwise (negative): down the left side, along the bottom from
    // left to right, then up the right side, leaving the opening at the top.
    final startAngle = -math.pi / 2 - gap / 2;
    final totalSweep = -(2 * math.pi - gap);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = trackColor;

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = progressColor;

    canvas.drawArc(rect, startAngle, totalSweep, false, trackPaint);

    final progressSweep = totalSweep * fraction;
    if (progressSweep != 0) {
      canvas.drawArc(rect, startAngle, progressSweep, false, progressPaint);
    }

    // Thumb.
    final thumbAngle = startAngle + progressSweep;
    final thumbCenter = Offset(
      center.dx + radius * math.cos(thumbAngle),
      center.dy + radius * math.sin(thumbAngle),
    );
    final r = dragging ? thumbRadius * 1.25 : thumbRadius;

    canvas.drawCircle(thumbCenter, r + 2, Paint()..color = thumbBorderColor);
    canvas.drawCircle(thumbCenter, r, Paint()..color = progressColor);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.dragging != dragging ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.thumbBorderColor != thumbBorderColor ||
      old.inset != inset;
}

/// Claims the touch immediately when it starts on the ring, so scrubbing wins
/// over the page's vertical scrolling; touches elsewhere are ignored.
class _RingGestureRecognizer extends OneSequenceGestureRecognizer {
  bool Function(Offset local)? hitTest;
  void Function(Offset local)? onStart;
  void Function(Offset local)? onUpdate;
  VoidCallback? onEnd;
  VoidCallback? onCancel;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!(hitTest?.call(event.localPosition) ?? false)) return;

    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onStart?.call(event.localPosition);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onUpdate?.call(event.localPosition);
    } else if (event is PointerUpEvent) {
      stopTrackingPointer(event.pointer);
      onEnd?.call();
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
      onCancel?.call();
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'ring scrub';
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