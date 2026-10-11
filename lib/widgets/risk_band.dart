import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../theme/ls_colors.dart';
import '../util/format.dart';

/// Tinted band with a solid left stripe in the band colour, the band word
/// and probability in ink, and the uncertainty range in muted ink. The word
/// always accompanies the colour, and the colour is never used as text.
class RiskBandView extends StatelessWidget {
  const RiskBandView({
    super.key,
    required this.band,
    required this.prob,
    required this.low,
    required this.high,
    this.showRange = true,
  });

  final RiskBand band;
  final double prob;
  final double low;
  final double high;

  /// False when the payment card has run out of height at a large text
  /// scale; the band word and probability always stay.
  final bool showRange;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final t = Theme.of(context).textTheme;
    final color = band.color(c);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: color.withValues(alpha: 0.18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 6, child: ColoredBox(color: color)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Copy.bandLabel(band.label, formatProb(prob)),
                        style: t.bodyLarge?.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (showRange)
                        Text(
                          Copy.probRange(formatProb(low), formatProb(high)),
                          style: t.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
