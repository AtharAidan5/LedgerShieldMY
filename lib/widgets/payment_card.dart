import 'dart:math';

import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../util/format.dart';
import '../util/measure.dart';
import 'category_chip.dart';
import 'countdown_bar.dart';
import 'ls_tag.dart';
import 'risk_band.dart';

/// The stateless card face. It carries no gesture code and never reads the
/// model rank, because the judge decides before the model's pick is shown.
///
/// The content is top-aligned with a muted row of gesture hints anchored at
/// the bottom. At large text scales the card measures what it needs and
/// degrades in a fixed order (tighter gaps, then the match-type tag, then
/// the gesture footer, then the uncertainty range, then a four-line cap on
/// the reason) rather than overflowing; every font stays at its theme size.
class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.item});

  final PoItem item;

  static const double _padding = 20;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _CardLayout.fit(context, item, constraints);
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: layout.showFooter ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(Copy.vendorLabel(item.vendor), style: t.bodySmall),
            Text(item.id, style: t.bodySmall?.merge(monoStyle)),
            SizedBox(height: layout.gapLarge),
            Text(
              formatUnits(item.exposureUnits),
              style: t.headlineMedium?.merge(monoStyle),
            ),
            Text(Copy.exposureCaption, style: t.bodySmall),
            SizedBox(height: layout.gapLarge),
            CountdownBar(days: item.daysToClearance),
            SizedBox(height: layout.gapLarge),
            RiskBandView(
              band: item.riskBand,
              prob: item.riskProb,
              low: item.riskLow,
              high: item.riskHigh,
              showRange: layout.showRange,
            ),
            SizedBox(height: layout.gapSmall),
            CategoryChip(category: item.category),
            SizedBox(height: layout.gapSmall),
            Text(
              item.reason,
              style: t.bodyLarge,
              maxLines: layout.reasonMaxLines,
              overflow: layout.reasonMaxLines == null
                  ? TextOverflow.clip
                  : TextOverflow.ellipsis,
            ),
            if (layout.showTag) ...[
              SizedBox(height: layout.gapSmall),
              _MatchTypeTag(text: item.matchType),
            ],
            if (layout.showFooter) ...[const Spacer(), const _GestureFooter()],
          ],
        );
        return Container(
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(_padding),
          decoration: lsCard(context),
          child: layout.scroll
              ? SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: column,
                )
              : column,
        );
      },
    );
  }
}

/// Which rows the card shows and how far apart, chosen from the measured
/// height of the content at the current text scale.
class _CardLayout {
  const _CardLayout({
    required this.gapLarge,
    required this.gapSmall,
    required this.showTag,
    required this.showFooter,
    required this.showRange,
    required this.reasonMaxLines,
    required this.scroll,
  });

  final double gapLarge;
  final double gapSmall;
  final bool showTag;
  final bool showFooter;
  final bool showRange;
  final int? reasonMaxLines;

  /// True when even the most compact layout does not fit: the column is
  /// then placed in a non-scrolling scroll view so the excess is clipped
  /// cleanly instead of raising a RenderFlex overflow.
  final bool scroll;

  static const double _large = 16;
  static const double _small = 12;
  static const double _tight = 8;
  static const int _reasonCap = 4;

  /// The layout for a card with no height limit, which is also the fallback
  /// when the constraints cannot be measured.
  static const _CardLayout unbounded = _CardLayout(
    gapLarge: _large,
    gapSmall: _small,
    showTag: true,
    showFooter: false,
    showRange: true,
    reasonMaxLines: null,
    scroll: false,
  );

  static _CardLayout fit(
    BuildContext context,
    PoItem item,
    BoxConstraints constraints,
  ) {
    final maxHeight = constraints.maxHeight;
    // The border adds 1 px on each side inside the padding.
    final inner = constraints.maxWidth - 2 * PaymentCard._padding - 2;
    if (!maxHeight.isFinite || !inner.isFinite || inner <= 0) return unbounded;

    final t = Theme.of(context).textTheme;
    final caption = t.bodySmall!;
    final body = t.bodyLarge!;
    final hero = scaledLineHeight(context, t.headlineMedium!);

    // Every text row is measured against the width it will actually get, so
    // a caption that wraps at a large text scale is counted at its wrapped
    // height rather than booked as one line.
    double rowHeight(String text, TextStyle style, double width) =>
        measureText(context, text, style, maxWidth: width).height;
    final vendor = rowHeight(Copy.vendorLabel(item.vendor), caption, inner);
    final id = rowHeight(item.id, caption.merge(monoStyle), inner);
    final heroCaption = rowHeight(Copy.exposureCaption, caption, inner);
    final countdownCaption = rowHeight(
      Copy.clearsIn(item.daysToClearance),
      caption,
      inner,
    );
    // The band text sits after a 6 px stripe and inside 12 px of padding on
    // each side; its label is 17 px semibold and the range is a caption.
    final bandWidth = max(inner - 6 - 24, 0.0);
    final bandLabel = rowHeight(
      Copy.bandLabel(item.riskBand.label, formatProb(item.riskProb)),
      body.copyWith(fontWeight: FontWeight.w600),
      bandWidth,
    );
    final bandRange = rowHeight(
      Copy.probRange(formatProb(item.riskLow), formatProb(item.riskHigh)),
      caption,
      bandWidth,
    );
    // A tag's text has 10 px of padding and a 1 px border on each side, and
    // the tag is 4 px of padding and the border taller than its text top and
    // bottom.
    final tagWidth = max(inner - 22, 0.0);
    final chipHeight =
        rowHeight(item.category.label, caption, tagWidth) + 10;
    final tagHeight = rowHeight(item.matchType, caption, tagWidth) + 10;

    final reasonFull = rowHeight(item.reason, body, inner);
    final reasonCapped = measureText(
      context,
      item.reason,
      body,
      maxWidth: inner,
      maxLines: _reasonCap,
    ).height;
    final footer = _GestureFooter.height(context, caption, inner);

    // Rows that are always present: vendor and id, hero and its caption,
    // the countdown (caption, 6 px gap, 3 px bar), the band (10 px padding
    // above and below its label), the chip, and the card padding and border.
    final fixed =
        vendor +
        id +
        hero +
        heroCaption +
        (countdownCaption + 6 + 3) +
        (20 + bandLabel) +
        chipHeight +
        2 * PaymentCard._padding +
        2;

    double needed(_CardLayout l, double reason) =>
        fixed +
        reason +
        3 * l.gapLarge +
        2 * l.gapSmall +
        (l.showRange ? bandRange : 0) +
        (l.showTag ? l.gapSmall + tagHeight : 0) +
        (l.showFooter ? l.gapLarge + footer : 0);
    bool fits(_CardLayout l, double reason) =>
        needed(l, reason) <= maxHeight + 0.5;

    const full = _CardLayout(
      gapLarge: _large,
      gapSmall: _small,
      showTag: true,
      showFooter: true,
      showRange: true,
      reasonMaxLines: null,
      scroll: false,
    );
    // The lowest-value rows go first: the gaps, then the match-type tag, then
    // the gesture footer (the buttons say the same), then the uncertainty
    // range, and only then is the reason capped.
    final steps = [
      full,
      full._with(gapLarge: _tight, gapSmall: _tight),
      full._with(gapLarge: _tight, gapSmall: _tight, showTag: false),
      full._with(
        gapLarge: _tight,
        gapSmall: _tight,
        showTag: false,
        showFooter: false,
      ),
      full._with(
        gapLarge: _tight,
        gapSmall: _tight,
        showTag: false,
        showFooter: false,
        showRange: false,
      ),
    ];
    for (final step in steps) {
      if (fits(step, reasonFull)) return step;
    }
    final capped = steps.last._with(reasonMaxLines: _reasonCap);
    if (fits(capped, reasonCapped)) return capped;
    return capped._with(scroll: true);
  }

  _CardLayout _with({
    double? gapLarge,
    double? gapSmall,
    bool? showTag,
    bool? showFooter,
    bool? showRange,
    int? reasonMaxLines,
    bool? scroll,
  }) {
    return _CardLayout(
      gapLarge: gapLarge ?? this.gapLarge,
      gapSmall: gapSmall ?? this.gapSmall,
      showTag: showTag ?? this.showTag,
      showFooter: showFooter ?? this.showFooter,
      showRange: showRange ?? this.showRange,
      reasonMaxLines: reasonMaxLines ?? this.reasonMaxLines,
      scroll: scroll ?? this.scroll,
    );
  }
}

class _MatchTypeTag extends StatelessWidget {
  const _MatchTypeTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    return LsTag(text: text, fill: c.line, border: c.line, textColor: c.ink);
  }
}

/// Three muted gesture hints along the bottom edge of the card: an arrow for
/// each swipe direction plus the one-word outcome, so all three fit on one
/// line even on a 375 px phone. They are hidden from the semantics tree
/// because the deck's own hint already tells a screen reader the same thing.
class _GestureFooter extends StatelessWidget {
  const _GestureFooter();

  static const double _spacing = 12;
  static const double _runSpacing = 4;
  static const double _icon = 16;
  static const double _iconGap = 4;

  static const List<(IconData, String)> _hints = [
    (Icons.arrow_back, Copy.footerSwipeLeft),
    (Icons.arrow_upward, Copy.footerSwipeUp),
    (Icons.arrow_forward, Copy.footerSwipeRight),
  ];

  /// The height the footer takes in a column [inner] px wide, laid out the
  /// same way [Wrap] lays out the hints below.
  static double height(BuildContext context, TextStyle caption, double inner) {
    var rows = 0;
    var x = 0.0;
    var rowHeight = 0.0;
    var total = 0.0;
    final textWidth = max(inner - _icon - _iconGap, 0.0);
    for (final (_, label) in _hints) {
      final text = measureText(context, label, caption, maxWidth: textWidth);
      final w = min(_icon + _iconGap + text.width, inner);
      final h = max(text.height, _icon);
      if (rows == 0 || x + _spacing + w > inner) {
        if (rows > 0) total += rowHeight + _runSpacing;
        rows++;
        x = w;
        rowHeight = h;
      } else {
        x += _spacing + w;
        rowHeight = max(rowHeight, h);
      }
    }
    return total + rowHeight;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final caption = Theme.of(context).textTheme.bodySmall!;
    return ExcludeSemantics(
      child: Wrap(
        spacing: _spacing,
        runSpacing: _runSpacing,
        alignment: WrapAlignment.spaceBetween,
        children: [
          for (final (icon, label) in _hints)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: _icon, color: c.inkMuted),
                const SizedBox(width: _iconGap),
                Flexible(child: Text(label, style: caption)),
              ],
            ),
        ],
      ),
    );
  }
}
