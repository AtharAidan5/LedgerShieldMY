import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../copy.dart';
import '../game/decision.dart';
import '../game/game_controller.dart';
import '../game/game_scope.dart';
import '../sheets/evidence_sheet.dart';
import '../sheets/how_it_works_dialog.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../theme/motion.dart';
import '../util/measure.dart';
import '../widgets/action_bar.dart';
import '../widgets/slot_tracker.dart';
import '../widgets/swipe_deck.dart';

/// Screen 1: the card stack, the opening line, the slot tracker and the
/// lock overlay. Every decision path (swipe, button, sheet) ends in exactly
/// one controller call, made from the deck's commit callback.
class StackScreen extends StatefulWidget {
  const StackScreen({super.key, this.onToggleTheme});

  /// Long-pressing the wordmark calls this; null means long-press does nothing.
  final VoidCallback? onToggleTheme;

  @override
  State<StackScreen> createState() => _StackScreenState();
}

class _StackScreenState extends State<StackScreen> {
  final SwipeCardController _deck = SwipeCardController();
  bool _sheetOpen = false;

  @override
  void dispose() {
    _deck.dispose();
    super.dispose();
  }

  GameController get _controller => GameScope.of(context);

  // Haptics wrap the controller calls so swipe, button and sheet paths all
  // feel the same. They stay on under reduced motion.

  void _hold(VoidCallback call) {
    final controller = _controller;
    final fillsLastSlot = controller.slotsUsed + 1 >= controller.k;
    if (fillsLastSlot) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    call();
  }

  void _release(VoidCallback call) {
    HapticFeedback.selectionClick();
    call();
  }

  void _swipeHold() =>
      _hold(() => _controller.hold(source: DecisionSource.swipe));

  void _swipeRelease() =>
      _release(() => _controller.release(source: DecisionSource.swipe));

  void _buttonHold() => _deck.fling(
    SwipeDirection.right,
    commit: () => _hold(() => _controller.hold(source: DecisionSource.button)),
  );

  void _buttonRelease() => _deck.fling(
    SwipeDirection.left,
    commit: () =>
        _release(() => _controller.release(source: DecisionSource.button)),
  );

  Future<void> _openEvidence() async {
    final controller = _controller;
    final item = controller.currentItem;
    // A card that is mid-fling is about to be decided, so it must not get a
    // sheet: the commit could lock the deck underneath an open sheet.
    if (_sheetOpen ||
        _deck.isCommitting ||
        item == null ||
        controller.phase != GamePhase.stack) {
      return;
    }
    _sheetOpen = true;
    final action = await showEvidenceSheet(context, item);
    _sheetOpen = false;
    if (!mounted || action == null) return;
    // The deck may have locked or moved on while the sheet was open; a stale
    // answer must never decide a different card.
    if (controller.phase != GamePhase.stack ||
        controller.currentItem?.id != item.id) {
      return;
    }
    switch (action) {
      case EvidenceAction.hold:
        _deck.fling(
          SwipeDirection.right,
          commit: () => _hold(
            () => controller.hold(
              source: DecisionSource.sheet,
              reason: Copy.holdReceivingReason,
            ),
          ),
        );
      case EvidenceAction.release:
        _deck.fling(
          SwipeDirection.left,
          commit: () =>
              _release(() => controller.release(source: DecisionSource.sheet)),
        );
      case EvidenceAction.escalate:
        _deck.fling(
          SwipeDirection.right,
          commit: () =>
              _hold(() => controller.escalate(source: DecisionSource.sheet)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = GameScope.of(context);
    final t = Theme.of(context).textTheme;
    final session = controller.session;
    final visible = session.skip(controller.currentIndex).toList();
    final active = controller.phase == GamePhase.stack;
    // Belt and braces: should the phase ever leave the stack while the sheet
    // is still up, pop the sheet so it never sits over the Reveal.
    if (_sheetOpen && !active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sheetOpen) Navigator.of(context).pop();
      });
    }
    final textScale = MediaQuery.textScalerOf(context).scale(17) / 17;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                used: controller.slotsUsed,
                k: controller.k,
                onToggleTheme: widget.onToggleTheme,
                onInfo: () => showHowItWorksDialog(context),
              ),
              const SizedBox(height: 8),
              // The 17 px lead and its 13 px explanation read as one
              // paragraph, to the eye and to a screen reader. Under large
              // system text the explanation goes first and then the lead, so
              // the card keeps its category and reason; the same framing
              // stays one tap away in the How-this-works dialog. Android
              // scales 17 sp non-linearly, so a 200 percent setting arrives
              // here as roughly 1.75, hence the thresholds below.
              if (textScale < 1.7) ...[
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Copy.opening(session.length, controller.k),
                        style: t.bodyLarge,
                      ),
                      if (textScale < 1.4) ...[
                        const SizedBox(height: 4),
                        Text(Copy.openingHint, style: t.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SwipeDeck(
                        controller: _deck,
                        items: visible,
                        cardNumber: controller.cardNumber,
                        total: session.length,
                        enabled: active,
                        onHold: _swipeHold,
                        onRelease: _swipeRelease,
                        onEvidence: _openEvidence,
                      ),
                    ),
                    if (controller.phase == GamePhase.locking)
                      _LockOverlay(
                        message: controller.slotsUsed >= controller.k
                            ? Copy.lockSlotsFull
                            : Copy.lockAllReviewed,
                        pause: controller.lockPause,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                Copy.cardCounter(controller.cardNumber, session.length),
                style: t.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ActionBar(
                enabled: active,
                onRelease: _buttonRelease,
                onEvidence: _openEvidence,
                onHold: _buttonHold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wordmark, slot tracker and the info button. The bar measures the wordmark
/// and the slot caption at the current text scale; when the three do not fit
/// one row it stacks the tracker under the wordmark and info button, so the
/// brand text is never cut.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.used,
    required this.k,
    required this.onToggleTheme,
    required this.onInfo,
  });

  final int used;
  final int k;
  final VoidCallback? onToggleTheme;
  final VoidCallback onInfo;

  static const double _infoButton = 48;
  static const double _gap = 8;

  /// Dot size and spacing, matching SlotTracker.
  static const double _dot = 12;
  static const double _dotGap = 6;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final t = Theme.of(context).textTheme;
    final wordmarkStyle = t.bodySmall!.copyWith(
      color: c.ink,
      fontWeight: FontWeight.w600,
    );
    final wordmark = _Wordmark(
      style: wordmarkStyle,
      onLongPress: onToggleTheme,
    );
    final tracker = SlotTracker(used: used, k: k);
    final info = IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: Copy.howItWorksTooltip,
      color: c.inkMuted,
      onPressed: onInfo,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wordmarkWidth = measureText(
          context,
          Copy.wordmark,
          wordmarkStyle,
        ).width;
        final captionWidth = measureText(
          context,
          Copy.slots(used, k),
          t.bodySmall!,
        ).width;
        final dotsWidth = k * _dot + (k - 1) * _dotGap;
        final needed =
            wordmarkWidth + _gap + max(dotsWidth, captionWidth) + _infoButton;
        if (needed <= constraints.maxWidth) {
          return Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: wordmark),
              ),
              const SizedBox(width: _gap),
              tracker,
              info,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: wordmark,
                  ),
                ),
                info,
              ],
            ),
            Align(alignment: Alignment.centerRight, child: tracker),
          ],
        );
      },
    );
  }
}

/// The brand text. A long press toggles the theme; the ink response and the
/// spoken hint make that discoverable, and the hit area is padded out to the
/// 48 px minimum touch target.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.style, required this.onLongPress});

  final TextStyle style;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: Copy.wordmark,
      hint: onLongPress == null ? null : Copy.wordmarkHint,
      onLongPress: onLongPress,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: c.ink.withValues(alpha: 0.06),
          highlightColor: c.ink.withValues(alpha: 0.04),
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(Copy.wordmark, style: style),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrim over the deck during the one-second pause before the Reveal. The
/// message sits in its own surface panel so it never reads through the card
/// text underneath, and it is announced as soon as the overlay builds. The
/// overlay also blocks the semantics of the deck beneath it, so a screen
/// reader cannot focus the covered top card while the message says the
/// remaining cards have been released.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.message, required this.pause});

  final String message;
  final Duration pause;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final t = Theme.of(context).textTheme;
    final reduce = reduceMotion(context);
    return Positioned.fill(
      child: BlockSemantics(
        child: ColoredBox(
          color: c.bg.withValues(alpha: 0.82),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: lsCard(context, radius: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: t.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // The bar is a decorative timer, not a control.
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 200,
                        child: reduce
                            ? _LockBar(value: 1, color: c)
                            : TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: pause,
                                builder: (context, value, _) =>
                                    _LockBar(value: value, color: c),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LockBar extends StatelessWidget {
  const _LockBar({required this.value, required this.color});

  final double value;
  final LsColors color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 4,
        color: color.accent,
        backgroundColor: color.line,
      ),
    );
  }
}
