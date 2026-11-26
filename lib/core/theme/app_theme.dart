import 'package:flutter/material.dart';

/// Gold palette used across the app. Light values are the original colors;
/// dark values keep the same gold identity on warm dark surfaces.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.card,
    required this.border,
    required this.gold,
    required this.goldText,
    required this.onGold,
    required this.goldSoft,
    required this.muted,
    required this.artworkStart,
    required this.artworkEnd,
    required this.shadow,
  });

  final Color background;
  final Color card;
  final Color border;
  final Color gold;
  final Color goldText;
  final Color onGold;
  final Color goldSoft;
  final Color muted;
  final Color artworkStart;
  final Color artworkEnd;
  final Color shadow;

  static const AppColors light = AppColors(
    background: Color(0xFFFFFCF5),
    card: Colors.white,
    border: Color(0xFFEFE5CE),
    gold: Color(0xFFC49A3A),
    goldText: Color(0xFF8A6A24),
    onGold: Colors.white,
    goldSoft: Color(0xFFFFF8E8),
    muted: Color(0xFF7D7567),
    artworkStart: Color(0xFFFFF8E5),
    artworkEnd: Color(0xFFE8D29A),
    shadow: Color(0x14000000),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF14110B),
    card: Color(0xFF1F1B13),
    border: Color(0xFF3B3322),
    gold: Color(0xFFD4A93F),
    goldText: Color(0xFFE8CC82),
    onGold: Color(0xFF1F1708),
    goldSoft: Color(0xFF2B2415),
    muted: Color(0xFFB3A98F),
    artworkStart: Color(0xFF3A2F17),
    artworkEnd: Color(0xFF1F1A0E),
    shadow: Color(0x66000000),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? card,
    Color? border,
    Color? gold,
    Color? goldText,
    Color? onGold,
    Color? goldSoft,
    Color? muted,
    Color? artworkStart,
    Color? artworkEnd,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      card: card ?? this.card,
      border: border ?? this.border,
      gold: gold ?? this.gold,
      goldText: goldText ?? this.goldText,
      onGold: onGold ?? this.onGold,
      goldSoft: goldSoft ?? this.goldSoft,
      muted: muted ?? this.muted,
      artworkStart: artworkStart ?? this.artworkStart,
      artworkEnd: artworkEnd ?? this.artworkEnd,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;

    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      artworkStart: Color.lerp(artworkStart, other.artworkStart, t)!,
      artworkEnd: Color.lerp(artworkEnd, other.artworkEnd, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: c.gold,
      brightness: brightness,
    ).copyWith(
      primary: c.gold,
      onPrimary: c.onGold,
      surface: c.card,
      outline: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.goldText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: c.goldText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: c.gold,
        inactiveTrackColor: c.border,
        thumbColor: c.gold,
        overlayColor: c.gold.withValues(alpha: 0.14),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.goldText,
        contentTextStyle: TextStyle(color: c.card),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: c.goldSoft,
        side: BorderSide(color: c.border),
        labelStyle: TextStyle(color: c.goldText, fontWeight: FontWeight.w600),
        checkmarkColor: c.gold,
      ),
    );
  }
}