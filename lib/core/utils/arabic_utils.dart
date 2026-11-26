class ArabicUtils {
  ArabicUtils._();

  static const String _indicDigits = '٠١٢٣٤٥٦٧٨٩';

  static final RegExp _diacritics = RegExp(r'[\u064B-\u065F\u0670\u0640]');
  static final RegExp _separators = RegExp(r"[\s\-_'’]");

  /// 114 -> ١١٤
  static String toArabicDigits(int value) {
    final buffer = StringBuffer();

    for (final unit in value.toString().codeUnits) {
      final char = String.fromCharCode(unit);
      final digit = int.tryParse(char);
      buffer.write(digit == null ? char : _indicDigits[digit]);
    }

    return buffer.toString();
  }

  /// Makes search forgiving:
  /// - removes tashkeel and tatweel
  /// - unifies alef / yaa / taa marbuta / hamza forms
  /// - converts Arabic-Indic digits to Latin digits
  /// - removes spaces, dashes and underscores (Al-An_aam == alanaam)
  static String normalize(String input) {
    var text = input.toLowerCase().replaceAll(_diacritics, '');

    text = text
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll(_separators, '');

    final buffer = StringBuffer();

    for (final rune in text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }

  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
    }

    return '$minutes:$ss';
  }
}