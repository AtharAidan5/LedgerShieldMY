import 'package:flutter/material.dart';

import '../copy.dart';
import '../util/measure.dart';

/// Release, Evidence and Hold for review. Each button is 48 px tall and every
/// label renders at its declared 17 px. The bar measures the three labels at
/// the current text scale and lays them out in one row when they fit, in two
/// rows (Hold for review alone on top, Release and Evidence sharing the
/// second row) when they do not, and in three rows as a last resort, so a
/// label is never scaled or truncated.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.onRelease,
    required this.onEvidence,
    required this.onHold,
    this.enabled = true,
  });

  final VoidCallback onRelease;
  final VoidCallback onEvidence;
  final VoidCallback onHold;
  final bool enabled;

  /// Keys that name the chosen layout, so a widget test can assert the
  /// switch without walking the tree.
  static const Key singleRowKey = Key('action-bar-single-row');
  static const Key twoRowKey = Key('action-bar-two-rows');
  static const Key threeRowKey = Key('action-bar-three-rows');

  static const double _height = 48;

  /// The same 8 px rhythm as the top bar and the Evidence sheet's action
  /// column, between buttons in a row and between stacked rows.
  static const double _gap = 8;
  static const double _labelPadding = 4;

  /// Room beyond the measured label so rounding never clips a glyph.
  static const double _slack = 2;

  // Material's 24 px button padding leaves too little room for three labels
  // in one row at phone width; 4 px keeps each label at full size down to a
  // 375 px wide screen.
  static const ButtonStyle _style = ButtonStyle(
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: _labelPadding),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge!;
    return LayoutBuilder(
      builder: (context, constraints) {
        double need(String label) =>
            measureText(context, label, labelStyle).width +
            2 * _labelPadding +
            _slack;
        final release = need(Copy.buttonRelease);
        final evidence = need(Copy.buttonEvidence);
        final hold = need(Copy.buttonHold);
        final width = constraints.maxWidth;

        // The single row splits its width 2 : 2 : 3, the same ratio the
        // Expanded flexes below use.
        final row = width - 2 * _gap;
        final singleFits =
            release <= row * 2 / 7 &&
            evidence <= row * 2 / 7 &&
            hold <= row * 3 / 7;
        if (singleFits) return _singleRow();

        final half = (width - _gap) / 2;
        final pairFits = release <= half && evidence <= half && hold <= width;
        if (pairFits) return _twoRows();

        return _threeRows();
      },
    );
  }

  Widget _singleRow() {
    return Row(
      key: singleRowKey,
      children: [
        Expanded(flex: 2, child: _release()),
        const SizedBox(width: _gap),
        Expanded(flex: 2, child: _evidence()),
        const SizedBox(width: _gap),
        Expanded(flex: 3, child: _hold()),
      ],
    );
  }

  Widget _twoRows() {
    return Column(
      key: twoRowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _hold(),
        const SizedBox(height: _gap),
        Row(
          children: [
            Expanded(child: _release()),
            const SizedBox(width: _gap),
            Expanded(child: _evidence()),
          ],
        ),
      ],
    );
  }

  Widget _threeRows() {
    return Column(
      key: threeRowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _hold(),
        const SizedBox(height: _gap),
        _release(),
        const SizedBox(height: _gap),
        _evidence(),
      ],
    );
  }

  Widget _release() => SizedBox(
    height: _height,
    child: FilledButton.tonal(
      style: _style,
      onPressed: enabled ? onRelease : null,
      child: const _Label(Copy.buttonRelease),
    ),
  );

  Widget _evidence() => SizedBox(
    height: _height,
    child: OutlinedButton(
      style: _style,
      onPressed: enabled ? onEvidence : null,
      child: const _Label(Copy.buttonEvidence),
    ),
  );

  Widget _hold() => SizedBox(
    height: _height,
    child: FilledButton(
      style: _style,
      onPressed: enabled ? onHold : null,
      child: const _Label(Copy.buttonHold),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // The bar has already measured this label into a slot that holds it, so
    // it is never allowed to wrap or shrink.
    return Text(text, maxLines: 1, softWrap: false);
  }
}
