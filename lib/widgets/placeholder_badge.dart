import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/ls_colors.dart';
import 'ls_tag.dart';

/// Small tinted tag that marks a number as sample data. The label is drawn
/// in ink on a riskMid tint, because riskMid alone fails contrast as text in
/// light mode.
class PlaceholderBadge extends StatelessWidget {
  const PlaceholderBadge({super.key, this.text = Copy.placeholder});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    return LsTag(
      text: text,
      fill: c.riskMid.withValues(alpha: 0.18),
      border: c.riskMid,
      textColor: c.ink,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
  }
}
