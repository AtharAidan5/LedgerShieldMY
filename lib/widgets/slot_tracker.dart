import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/ls_colors.dart';
import '../theme/motion.dart';

/// Five dots that fill as review slots are used, with "Review slots 2/5"
/// underneath. Stacking the label under the dots keeps the top bar inside
/// 343 px on a 375 px phone next to the wordmark and the info button.
class SlotTracker extends StatelessWidget {
  const SlotTracker({super.key, required this.used, required this.k});

  final int used;
  final int k;

  @override
  Widget build(BuildContext context) {
    // A screen reader hears the caption once; the dots repeat it visually.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: Copy.slots(used, k),
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < k; i++) ...[
                  SlotDot(filled: i < used),
                  if (i < k - 1) const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              Copy.slots(used, k),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// One slot dot. It pulses once when [filled] flips to true, unless the
/// platform asks for reduced motion.
class SlotDot extends StatefulWidget {
  const SlotDot({super.key, required this.filled});

  final bool filled;

  @override
  State<SlotDot> createState() => _SlotDotState();
}

class _SlotDotState extends State<SlotDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: slotPulse,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void didUpdateWidget(SlotDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.filled && widget.filled && !reduceMotion(context)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.filled ? c.accent : Colors.transparent,
          // The empty ring is drawn in muted ink rather than line: line on
          // the background is about 1.2:1, far below the 3:1 a graphic needs.
          border: widget.filled
              ? null
              : Border.all(color: c.inkMuted, width: 1.5),
        ),
      ),
    );
  }
}
