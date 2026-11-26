import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app logo: the reciter's photo inside a gold double ring.
///
/// It is drawn with widgets (not a baked PNG) so it stays sharp at any size
/// and follows the light / dark gold palette. It matches the generated
/// launcher icon and splash images in `assets/icon/`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  /// The reciter photo, also used as the player artwork.
  static const String photoAsset = 'assets/images/alafasy.jpg';

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final outerRing = size * 0.030;
    final gap = size * 0.025;
    final innerRing = size * 0.011;
    final photoInset = outerRing + gap + innerRing + size * 0.019;

    return Semantics(
      label: 'شعار التطبيق',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.card,
          border: Border.all(color: colors.gold, width: outerRing),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: size * 0.12,
              offset: Offset(0, size * 0.04),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.gold.withValues(alpha: 0.55),
                width: innerRing,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(photoInset - outerRing - gap - innerRing),
              child: ClipOval(
                child: Image.asset(
                  photoAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: colors.goldSoft,
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: colors.gold,
                      size: size * 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}