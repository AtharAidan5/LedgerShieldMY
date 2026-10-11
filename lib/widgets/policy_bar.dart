import 'dart:math';

import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../util/format.dart';

/// One horizontal bar on the Proof receipt: a policy name, its recall at K
/// drawn as a filled fraction of the track, and the value in mono. The
/// receipt's banner, not the row, says when the number is still sample data.
class PolicyBar extends StatelessWidget {
  const PolicyBar({
    super.key,
    required this.label,
    required this.value,
    required this.highlighted,
  });

  final String label;

  /// Share of future exceptions surfaced, in 0..1.
  final double value;

  /// True for the LedgerShield row, which fills in accent; others use inkMuted.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final text = Theme.of(context).textTheme;
    // A zero placeholder still draws a sliver so the row reads as a bar.
    final fraction = max(value, 0.02).clamp(0.0, 1.0).toDouble();
    final valueText = formatProb(value);
    // One spoken phrase per row: the bar itself is decorative.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: Copy.labelledValue(label, valueText),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(color: c.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valueText,
                style: text.bodySmall?.merge(monoStyle).copyWith(color: c.ink),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              // The same muted-ink track as the card's countdown bar, so the
              // full extent of the bar reads on both surfaces even when the
              // fill is only the 2 percent sliver; the two bars stay in step.
              color: c.inkMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlighted ? c.accent : c.inkMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
