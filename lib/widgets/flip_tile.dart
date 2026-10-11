import 'dart:math';

import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../util/format.dart';

/// One tile of the "What actually happened" grid on the Reveal.
///
/// The tile drives a 3D flip from [animation]: the neutral front (id and
/// exposure) for `t < 0.5`, then the outcome back for `t >= 0.5`. The back
/// is wrapped in an extra half-turn so its text is not mirrored.
class FlipTile extends StatelessWidget {
  const FlipTile({
    super.key,
    required this.animation,
    required this.item,
    required this.yourPick,
    required this.modelPick,
  });

  final Animation<double> animation;
  final PoItem item;
  final bool yourPick;
  final bool modelPick;

  @override
  Widget build(BuildContext context) {
    // Both faces are built once here, so each animation frame only costs one
    // Transform around a prebuilt subtree.
    final front = _FrontFace(item: item);
    final back = _BackFace(
      item: item,
      yourPick: yourPick,
      modelPick: modelPick,
    );
    final isException = item.outcome.exceptionReachedClearance;
    // A screen reader hears one phrase per tile, the same on both faces, so
    // the flip never makes a node appear or vanish under focus.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: Copy.tileSemantics(
        vendor: item.vendor,
        exposure: formatUnits(item.exposureUnits),
        outcome: isException ? Copy.exception : Copy.fine,
        yourPick: yourPick,
        modelPick: modelPick,
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          // The perspective entry must be set before the rotation is applied.
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(t * pi);
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: t >= 0.5
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: back,
                  )
                : front,
          );
        },
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  const _FrontFace({required this.item});

  final PoItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final caption = Theme.of(context).textTheme.bodySmall!;
    // A 4-column tile is about 80 px wide on a 375 px phone, so the neutral
    // front shows the vendor and the exposure, which are what the picks
    // columns above also show; the full id would not fit at 13 px. The
    // Reveal picks the column count so both lines fit at any text scale.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.vendor,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: caption.merge(monoStyle).copyWith(color: c.ink),
          ),
          const SizedBox(height: 4),
          Text(
            formatUnits(item.exposureUnits),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: caption.merge(monoStyle),
          ),
        ],
      ),
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({
    required this.item,
    required this.yourPick,
    required this.modelPick,
  });

  final PoItem item;
  final bool yourPick;
  final bool modelPick;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final caption = Theme.of(context).textTheme.bodySmall!;
    final isException = item.outcome.exceptionReachedClearance;
    final tone = isException ? c.riskHigh : c.accent;
    final word = isException ? Copy.exception : Copy.fine;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: tone.withValues(alpha: 0.18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: tone),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      word,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption.copyWith(
                        color: c.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (yourPick || modelPick) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (yourPick) Copy.markerYou,
                          if (modelPick) Copy.markerModel,
                        ].join(' + '),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: caption.copyWith(color: c.ink),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
