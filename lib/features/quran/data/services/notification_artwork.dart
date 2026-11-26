import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

/// Renders the square artwork shown in the system media notification
/// (notification shade + lock screen) and caches it on disk.
///
/// The image is drawn once with a Canvas, so no extra asset is needed and the
/// look matches the in-app gold artwork. If anything fails the notification
/// simply falls back to no artwork.
class NotificationArtwork {
  NotificationArtwork._();

  static const int _size = 512;

  // Bump the version suffix whenever the drawing below changes.
  static const String _fileName = 'notification_artwork_v1.png';

  static const Color _gold = Color(0xFFD4A93F);
  static const Color _goldText = Color(0xFFE8CC82);

  static Future<Uri?> ensureCreated() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_fileName');

      if (await file.exists() && await file.length() > 0) {
        return file.uri;
      }

      final bytes = await _render();
      if (bytes == null) return null;

      // Write to a temp file first so a crash can never leave a half-written
      // image behind.
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);

      return file.uri;
    } catch (_) {
      return null;
    }
  }

  static Future<List<int>?> _render() async {
    const side = 512.0;
    const center = Offset(side / 2, side / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Warm dark background with a soft diagonal gradient.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, side, side),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(side, side),
          const [Color(0xFF3A2F17), Color(0xFF14110B)],
        ),
    );

    // Soft glow behind the emblem.
    canvas.drawCircle(
      center,
      side * 0.42,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          side * 0.42,
          [_gold.withValues(alpha: 0.28), _gold.withValues(alpha: 0)],
        ),
    );

    // Double gold ring.
    final ring = Paint()..style = PaintingStyle.stroke;

    canvas.drawCircle(
      center,
      side * 0.40,
      ring
        ..strokeWidth = 10
        ..color = _gold,
    );
    canvas.drawCircle(
      center,
      side * 0.34,
      ring
        ..strokeWidth = 3
        ..color = _gold.withValues(alpha: 0.65),
    );

    // Title.
    final painter = TextPainter(
      text: const TextSpan(
        text: 'القرآن\nالكريم',
        style: TextStyle(
          color: _goldText,
          fontSize: side * 0.125,
          fontWeight: FontWeight.bold,
          height: 1.35,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(minWidth: side * 0.55, maxWidth: side * 0.55);

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(_size, _size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    image.dispose();
    picture.dispose();

    return data?.buffer.asUint8List();
  }
}