import 'package:flutter/material.dart';

TextDirection textDirectionForText(String value) {
  for (final rune in value.runes) {
    if (_isRtlRune(rune)) {
      return TextDirection.rtl;
    }
    if (_isLtrRune(rune)) {
      return TextDirection.ltr;
    }
  }
  return TextDirection.ltr;
}

class BidiText extends StatelessWidget {
  const BidiText(
    this.text, {
    this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final direction = textDirectionForText(text);
    return Directionality(
      textDirection: direction,
      child: Text(
        text,
        textAlign: direction == TextDirection.rtl ? TextAlign.right : null,
        softWrap: true,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

bool _isRtlRune(int rune) {
  return (rune >= 0x0590 && rune <= 0x08FF) ||
      (rune >= 0xFB1D && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFF);
}

bool _isLtrRune(int rune) {
  return (rune >= 0x0041 && rune <= 0x005A) ||
      (rune >= 0x0061 && rune <= 0x007A);
}
