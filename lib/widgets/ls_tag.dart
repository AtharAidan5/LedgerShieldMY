import 'package:flutter/material.dart';

/// The one small tag spec shared by the category chip, the match-type tag
/// and the placeholder badge: 13 px text, 10 by 4 padding, a 1 px border and
/// an 8 px radius, which gives every tag the same 27 px height. Variants
/// differ only in fill, border and text colour.
class LsTag extends StatelessWidget {
  const LsTag({
    super.key,
    required this.text,
    required this.border,
    required this.textColor,
    this.fill,
    this.fontWeight,
    this.letterSpacing,
  });

  final String text;
  final Color border;
  final Color textColor;
  final Color? fill;
  final FontWeight? fontWeight;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}
