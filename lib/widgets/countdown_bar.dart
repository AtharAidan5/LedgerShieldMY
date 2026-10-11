import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/ls_colors.dart';

/// "Clears in 6 days" with a thin bar that fills as clearance approaches.
class CountdownBar extends StatelessWidget {
  const CountdownBar({super.key, required this.days});

  /// Days left until the item clears for payment.
  final int days;

  /// The bar treats 30 days as the full warning window.
  static const double _windowDays = 30;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final fraction = (1 - days / _windowDays).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(Copy.clearsIn(days), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: ColoredBox(
              // A muted-ink track keeps the remaining portion visible on the
              // card surface; the text above carries the value.
              color: c.inkMuted.withValues(alpha: 0.35),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: ColoredBox(color: c.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
