import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../copy.dart';
import '../data/models.dart';
import '../theme/ls_colors.dart';
import '../theme/motion.dart';
import '../util/format.dart';
import 'payment_card.dart';

enum SwipeDirection { left, right }

/// Lets the action bar and the Evidence sheet drive the top card through the
/// same commit animation a swipe uses. The deck attaches itself in initState.
class SwipeCardController extends ChangeNotifier {
  _SwipeDeckState? _state;

  /// True while the top card is flying off screen and its decision has not
  /// been recorded yet. Callers that would act on the current card (such as
  /// opening the Evidence sheet) must wait until this is false.
  bool get isCommitting => _state?._committing ?? false;

  /// Flings the top card off screen in [direction] and then runs [commit].
  /// When [commit] is null the deck's own swipe default for that direction
  /// runs instead. Exactly one commit runs per fling.
  void fling(SwipeDirection direction, {VoidCallback? commit}) {
    _state?._flingFromRest(direction, commit);
  }
}

/// Up to three payment cards: the top card is draggable, the two behind it
/// peek out below it and move forward when the top card leaves.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.controller,
    required this.items,
    required this.cardNumber,
    required this.total,
    required this.onHold,
    required this.onRelease,
    required this.onEvidence,
    this.enabled = true,
  });

  final SwipeCardController controller;

  /// Remaining items, top card first. Only the first three are rendered.
  final List<PoItem> items;

  /// One-based position of the top card in the session, for the spoken
  /// "Card n of N".
  final int cardNumber;
  final int total;

  /// Default commit for a right swipe.
  final VoidCallback onHold;

  /// Default commit for a left swipe.
  final VoidCallback onRelease;

  /// Runs on tap and on an up swipe.
  final VoidCallback onEvidence;

  final bool enabled;

  @override
  State<SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  static const double _horizontalCommitFraction = 0.35;
  static const double _upCommitFraction = 0.25;
  static const double _commitVelocity = 800;
  static const double _maxRotation = 0.26;
  static const int _visibleCards = 3;
  static const List<double> _scales = [1.0, 0.96, 0.92];
  static const List<double> _downOffsets = [0, 12, 24];

  /// Space kept free below the top card so the two back cards, offset 12 and
  /// 24 px downward, show as thin bands beneath it instead of being hidden.
  static const double _peek = 24;

  /// How far the top card shrinks while a finger rests on it.
  static const double _pressedScale = 0.985;
  static const Duration _pressDuration = Duration(milliseconds: 90);

  late final AnimationController _anim = AnimationController.unbounded(
    vsync: this,
  );
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _pressed = ValueNotifier(false);
  late final Listenable _motion = Listenable.merge([_anim, _drag]);

  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _committing = false;
  final List<(SwipeDirection, VoidCallback?)> _pending = [];
  bool _dragging = false;
  bool _reduce = false;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = reduceMotion(context);
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller._state == this) {
        oldWidget.controller._state = null;
      }
      widget.controller._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) {
      widget.controller._state = null;
    }
    _anim.dispose();
    _drag.dispose();
    _pressed.dispose();
    super.dispose();
  }

  // The offset the top card is drawn at this frame.
  Offset _rendered() =>
      _anim.isAnimating ? Offset.lerp(_from, _to, _anim.value)! : _drag.value;

  // Gestures.

  void _onPanStart(DragStartDetails details) {
    // A drag never starts from a shrunken card.
    _pressed.value = false;
    if (_committing || !widget.enabled) return;
    if (_anim.isAnimating) {
      // Continue from where the spring left the card instead of jumping.
      _anim.stop();
      _drag.value = Offset.lerp(_from, _to, _anim.value)!;
    }
    _dragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    _drag.value += details.delta;
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond;
    final drag = _drag.value;
    final fast = velocity.dx.abs() > _commitVelocity;
    if (drag.dx.abs() > _horizontalCommitFraction * _size.width || fast) {
      final dx = fast ? velocity.dx : drag.dx;
      if (dx > 0) {
        _commit(SwipeDirection.right, widget.onHold);
      } else {
        _commit(SwipeDirection.left, widget.onRelease);
      }
      return;
    }
    final up =
        drag.dy < -_upCommitFraction * _size.height &&
        drag.dy.abs() > drag.dx.abs();
    _springBack(details.velocity);
    if (up) widget.onEvidence();
  }

  void _onPanCancel() {
    if (!_dragging) return;
    _dragging = false;
    _springBack(Velocity.zero);
  }

  // Animations.

  void _flingFromRest(SwipeDirection direction, VoidCallback? commit) {
    if (!widget.enabled || widget.items.isEmpty) return;
    if (_committing) {
      // A tap that lands during the 220 ms commit of the previous card is
      // queued, not dropped, so rapid tapping never loses a decision. Each
      // queued request is replayed in order once the deck is at rest.
      _pending.add((direction, commit));
      return;
    }
    _dragging = false;
    if (_anim.isAnimating) _anim.stop();
    _drag.value = Offset.zero;
    final fallback = direction == SwipeDirection.right
        ? widget.onHold
        : widget.onRelease;
    _commit(direction, commit ?? fallback);
  }

  void _commit(SwipeDirection direction, VoidCallback commit) {
    _committing = true;
    final sign = direction == SwipeDirection.right ? 1.0 : -1.0;
    _from = _drag.value;
    _to = Offset(sign * _size.width * 1.5, _from.dy);
    _anim.value = 0;
    if (_reduce || _size.width == 0) {
      _finishCommit(commit);
      return;
    }
    setState(() {});
    _anim
        .animateTo(1, duration: commitDuration, curve: Curves.easeOut)
        .whenComplete(() => _finishCommit(commit));
  }

  void _finishCommit(VoidCallback commit) {
    if (!mounted) return;
    _committing = false;
    _from = Offset.zero;
    _to = Offset.zero;
    _drag.value = Offset.zero;
    _anim.value = 0;
    commit();
    if (!mounted) return;
    setState(() {});
    if (_pending.isNotEmpty) {
      final next = _pending.removeAt(0);
      // Replay after this frame so the next card is laid out first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _flingFromRest(next.$1, next.$2);
      });
    }
  }

  void _springBack(Velocity velocity) {
    _from = _drag.value;
    _to = Offset.zero;
    if (_reduce || _from == Offset.zero) {
      _anim.value = 1;
      _drag.value = Offset.zero;
      return;
    }
    _anim.value = 0;
    // The simulation runs 0 to 1 over the tween from the drag offset back to
    // centre, so the start velocity is expressed in tween units per second.
    final v = _from.dx.abs() < 1
        ? 0.0
        : -velocity.pixelsPerSecond.dx / _from.dx;
    _anim
        .animateWith(SpringSimulation(cardSpring, 0, 1, v))
        .whenComplete(_onSpringDone);
  }

  void _onSpringDone() {
    if (!mounted || _committing || _dragging) return;
    _drag.value = Offset.zero;
  }

  // Build.

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final items = widget.items.take(_visibleCards).toList();
        final move = _reduce ? Duration.zero : backCardMove;
        // Every card is laid out in the same slot, _peek px short of the
        // deck's bottom edge; the downward offsets then push the back cards
        // into that reserved band so they peek out below the top card. The
        // back cards scale about their bottom edge, so shrinking them never
        // lifts that edge back up and the slide offsets are the visible peek:
        // the depth-2 card's bottom lands exactly on the deck's bottom edge.
        final cardHeight = _size.height - _peek;
        return Stack(
          children: [
            for (var depth = items.length - 1; depth >= 0; depth--)
              Positioned(
                key: ValueKey(items[depth].id),
                left: 0,
                right: 0,
                top: 0,
                bottom: _peek,
                child: AnimatedScale(
                  scale: _scales[depth],
                  alignment: Alignment.bottomCenter,
                  duration: move,
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: Offset(
                      0,
                      cardHeight > 0 && cardHeight.isFinite
                          ? _downOffsets[depth] / cardHeight
                          : 0,
                    ),
                    duration: move,
                    curve: Curves.easeOut,
                    child: depth == 0
                        ? _buildTop(items[depth])
                        : ExcludeSemantics(
                            child: RepaintBoundary(
                              child: PaymentCard(item: items[depth]),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTop(PoItem item) {
    final interactive = widget.enabled && !_committing;
    final c = context.ls;
    // The card's own text is excluded: one spoken description per card, with
    // the gestures and buttons in the hint, replaces a dozen separate nodes.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: Copy.cardSemantics(
        vendor: item.vendor,
        exposure: formatUnits(item.exposureUnits),
        band: item.riskBand.label,
        prob: formatProb(item.riskProb),
        category: item.category.label,
        reason: item.reason,
        n: widget.cardNumber,
        total: widget.total,
      ),
      hint: Copy.cardSemanticsHint,
      onTap: interactive ? widget.onEvidence : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: interactive ? widget.onEvidence : null,
        // The press callbacks live in the tap recogniser, so they never
        // compete with the pan arena.
        onTapDown: interactive ? (_) => _pressed.value = true : null,
        onTapUp: (_) => _pressed.value = false,
        onTapCancel: () => _pressed.value = false,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        child: AnimatedBuilder(
          animation: _motion,
          child: ValueListenableBuilder<bool>(
            valueListenable: _pressed,
            child: PaymentCard(item: item),
            builder: (context, pressed, child) => AnimatedScale(
              scale: pressed ? _pressedScale : 1,
              duration: motionOr(context, _pressDuration),
              curve: Curves.easeOut,
              child: child,
            ),
          ),
          builder: (context, child) {
            final offset = _rendered();
            final width = _size.width;
            final angle = _reduce || width == 0
                ? 0.0
                : offset.dx / width * _maxRotation;
            final transform = Matrix4.translationValues(offset.dx, offset.dy, 0)
              ..rotateZ(angle);
            return Transform(
              transform: transform,
              alignment: Alignment.bottomCenter,
              child: Stack(
                fit: StackFit.expand,
                children: [child!, _hints(offset, c)],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hints(Offset offset, LsColors c) {
    final width = _size.width;
    final height = _size.height;
    // The pill is fully opaque at 60 percent of the commit distance, so it
    // reads as a clear badge well before the card is let go.
    final horizontal = width == 0
        ? 0.0
        : (offset.dx.abs() / (0.6 * _horizontalCommitFraction * width)).clamp(
            0.0,
            1.0,
          );
    final upward =
        height == 0 || offset.dy >= 0 || offset.dy.abs() <= offset.dx.abs()
        ? 0.0
        : (-offset.dy / (_upCommitFraction * height)).clamp(0.0, 1.0);
    // Each pill sits on the corner opposite the drag direction: a card
    // dragged left leaves the screen on its left edge first, so the Release
    // pill stays visible at the top right, and the Hold pill mirrors that.
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              right: 20,
              child: Opacity(
                opacity: offset.dx < 0 ? horizontal : 0,
                child: _HintPill(
                  icon: Icons.check,
                  label: Copy.hintRelease,
                  color: c.inkMuted,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: Opacity(
                opacity: offset.dx > 0 ? horizontal : 0,
                child: _HintPill(
                  icon: Icons.pan_tool_outlined,
                  label: Copy.hintHold,
                  color: c.accent,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: upward,
                  child: _HintPill(
                    icon: Icons.search,
                    label: Copy.hintEvidence,
                    color: c.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The larger pill that fades in over the card during a drag. It is a 17 px
/// overlay, not an inline tag, so it keeps its own fully round shape.
class _HintPill extends StatelessWidget {
  const _HintPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // The screen background, not the card surface, so the badge stands
        // off the card text it overlaps.
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: t.bodyLarge?.copyWith(
              color: c.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
