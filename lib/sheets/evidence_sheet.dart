import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../theme/motion.dart';
import '../util/format.dart';

/// What the reviewer chose on the Evidence sheet. The sheet only reports the
/// choice; the StackScreen turns it into a deck fling and a controller call.
enum EvidenceAction { hold, release, escalate }

/// The snap duration under reduced motion. DraggableScrollableSheet asserts
/// that the value is above zero, so one millisecond stands in for "instant":
/// the snapping simulation derives its velocity from this duration, which
/// makes the sheet land on the next snap point in the same frame.
const Duration _snapInstant = Duration(milliseconds: 1);
const Duration _snapDuration = Duration(milliseconds: 200);

/// Opens Screen 2 for [item] and resolves with the reviewer's choice, or null
/// when the sheet is dismissed by drag, scrim tap or system back.
///
/// Reduce-motion is read from the caller's [context] before the modal route
/// exists, because the sheet's own context sits under that route.
Future<EvidenceAction?> showEvidenceSheet(BuildContext context, PoItem item) {
  final reduce = reduceMotion(context);
  final c = context.ls;
  return showModalBottomSheet<EvidenceAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    sheetAnimationStyle: reduce
        ? AnimationStyle.noAnimation
        : const AnimationStyle(duration: sheetIn, reverseDuration: sheetOut),
    builder: (_) => EvidenceSheet(item: item),
  );
}

/// The sheet body: handle, title, timeline, vendor base rate, what would
/// change, recommended action, the three actions and the footer note.
class EvidenceSheet extends StatelessWidget {
  const EvidenceSheet({super.key, required this.item});

  final PoItem item;

  @override
  Widget build(BuildContext context) {
    // With large system text the sheet opens at its full height, otherwise
    // the three action buttons leave almost no room for the timeline.
    final largeText = MediaQuery.textScalerOf(context).scale(17) >= 17 * 1.5;
    final initial = largeText ? 0.95 : 0.8;
    return DraggableScrollableSheet(
      initialChildSize: initial,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: [initial],
      snapAnimationDuration: reduceMotion(context)
          ? _snapInstant
          : _snapDuration,
      builder: (ctx, scroll) {
        // Insets and padding come from the sheet's own context, which sits
        // under the modal route; the caller's context would report the
        // screen behind the scrim.
        final insets = MediaQuery.viewInsetsOf(ctx);
        final padding = MediaQuery.paddingOf(ctx);
        final bottom = math.max(insets.bottom, padding.bottom);
        return Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  const _Handle(),
                  const SizedBox(height: 16),
                  _Title(item: item),
                  const SizedBox(height: 20),
                  _Timeline(events: item.events),
                  const SizedBox(height: 20),
                  _VendorBaseRate(rate: item.vendorBaseRate),
                  const SizedBox(height: 16),
                  _LabelledLine(
                    label: Copy.whatWouldChangeLabel,
                    text: item.whatWouldChange,
                  ),
                  const SizedBox(height: 16),
                  _LabelledLine(
                    label: Copy.recommendedActionLabel,
                    text: Copy.recommendedAction(item.category),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionRow(
                    onHold: () => Navigator.of(ctx).pop(EvidenceAction.hold),
                    onRelease: () =>
                        Navigator.of(ctx).pop(EvidenceAction.release),
                    onEscalate: () =>
                        Navigator.of(ctx).pop(EvidenceAction.escalate),
                  ),
                  const SizedBox(height: 8),
                  const _FooterNote(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.ls.line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.item});

  final PoItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(Copy.evidenceTitle(item.vendor), style: text.titleLarge),
        const SizedBox(height: 4),
        Text(item.id, style: text.bodySmall!.merge(monoStyle)),
      ],
    );
  }
}

/// One row per event. Present events get a solid accent dot and their date;
/// missing events get a hollow dashed dot in the high-risk colour and a
/// "not recorded" label. Vertical connectors join the dots.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});

  final List<PoEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final PoEvent event;
  final bool isFirst;
  final bool isLast;

  static const double _dot = 10;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final text = Theme.of(context).textTheme;
    // Label and date are one spoken row.
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Expanded(child: _Connector(visible: !isFirst)),
                  SizedBox(
                    width: _dot,
                    height: _dot,
                    child: event.present
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : CustomPaint(
                            painter: _DashedCirclePainter(color: c.riskHigh),
                          ),
                  ),
                  Expanded(child: _Connector(visible: !isLast)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: event.present
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(event.label, style: text.bodyLarge),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            formatDate(event.date),
                            style: text.bodySmall!.merge(monoStyle),
                          ),
                        ],
                      )
                    : Text(
                        Copy.notRecorded(event.label),
                        style: text.bodyLarge!.copyWith(color: c.riskHigh),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 1.5,
        child: visible
            ? ColoredBox(color: context.ls.line, child: const SizedBox.expand())
            : const SizedBox.expand(),
      ),
    );
  }
}

/// A hollow circle with a dashed 1.5 px outline (4 px dash, 3 px gap).
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  static const double _stroke = 1.5;
  static const double _dash = 4;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final rect = Rect.fromLTWH(
      _stroke / 2,
      _stroke / 2,
      size.width - _stroke,
      size.height - _stroke,
    );
    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = math.min(start + _dash, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _VendorBaseRate extends StatelessWidget {
  const _VendorBaseRate({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    return Text(
      Copy.vendorBaseRate(formatPercent(rate)),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class _LabelledLine extends StatelessWidget {
  const _LabelledLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(text, style: textTheme.bodyLarge),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onHold,
    required this.onRelease,
    required this.onEscalate,
  });

  final VoidCallback onHold;
  final VoidCallback onRelease;
  final VoidCallback onEscalate;

  static const Size _buttonSize = Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: onHold,
          // The long label wraps to two lines on a phone, so it is centred
          // and given room above and below to look intended.
          style: FilledButton.styleFrom(
            minimumSize: _buttonSize,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: const Text(Copy.sheetHold, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: onRelease,
          style: FilledButton.styleFrom(minimumSize: _buttonSize),
          child: const Text(Copy.sheetRelease),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onEscalate,
          style: TextButton.styleFrom(minimumSize: _buttonSize),
          child: const Text(Copy.sheetEscalate),
        ),
      ],
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      Copy.sheetFooter,
      style: Theme.of(context).textTheme.bodySmall,
      textAlign: TextAlign.center,
    );
  }
}
