import 'package:flutter/widgets.dart';

/// Lays out [text] in [style] at the ambient text scale and returns its size.
///
/// Adaptive layouts (the action bar, the top bar, the payment card and the
/// Reveal grid) measure their labels with this before choosing a layout, so
/// text is rearranged at large font sizes rather than scaled or truncated.
Size measureText(
  BuildContext context,
  String text,
  TextStyle style, {
  double maxWidth = double.infinity,
  int? maxLines,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
  )..layout(maxWidth: maxWidth);
  final size = painter.size;
  painter.dispose();
  return size;
}

/// The height of one line of [style] at the ambient text scale. Every theme
/// style sets an explicit `height`, so a line is exactly `fontSize * height`.
double scaledLineHeight(BuildContext context, TextStyle style) {
  final scaled = MediaQuery.textScalerOf(context).scale(style.fontSize!);
  return scaled * (style.height ?? 1.0);
}
