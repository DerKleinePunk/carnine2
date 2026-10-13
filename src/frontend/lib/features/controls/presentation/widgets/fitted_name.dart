import 'package:flutter/widgets.dart';

/// The name of a switch or slider as the user typed it (#96). It breaks only
/// between words, in at most [maxLines] lines; when a single word is wider
/// than the space - "Zusatzscheinwerfer" on a card four to a row - the font
/// gets smaller, in steps, until the word fits. Only below [minFontSize] a
/// word is broken after all, with an ellipsis at the end.
class FittedName extends StatelessWidget {
  const FittedName({
    required this.name,
    required this.style,
    this.minFontSize = 12,
    this.maxLines = 2,
    super.key,
  });

  final String name;

  /// The size in [style] is the largest one that is used.
  final TextStyle style;
  final double minFontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largest = style.fontSize ?? 14;
        final size = fittingFontSize(
          name,
          style: style,
          maxWidth: constraints.maxWidth,
          maxLines: maxLines,
          largest: largest,
          smallest: minFontSize < largest ? minFontSize : largest,
          textDirection: Directionality.of(context),
        );

        return Text(
          name,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }

  /// The largest font size from [largest] down to [smallest], in steps of half
  /// a point, at which [text] fits into [maxWidth] and [maxLines] without
  /// breaking a word; [smallest] when none does.
  @visibleForTesting
  static double fittingFontSize(
    String text, {
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required double largest,
    required double smallest,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return largest;
    }
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var size = largest;
    while (size > smallest) {
      final sized = style.copyWith(fontSize: size);
      if (_fits(text, words, sized, maxWidth, maxLines, textDirection)) {
        return size;
      }
      size -= 0.5;
    }
    return smallest;
  }

  static bool _fits(
    String text,
    Iterable<String> words,
    TextStyle style,
    double maxWidth,
    int maxLines,
    TextDirection textDirection,
  ) {
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      if (width > maxWidth) {
        return false;
      }
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return !exceeded;
  }
}
