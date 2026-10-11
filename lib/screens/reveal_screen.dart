import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../game/game_controller.dart';
import '../game/game_scope.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../theme/motion.dart';
import '../util/format.dart';
import '../util/measure.dart';
import '../widgets/flip_tile.dart';
import 'audit_screen.dart';

/// Delay between the first frame of the Reveal and the first tile flip, so
/// the judge sees the neutral grid before it turns over.
const Duration _flipStartDelay = Duration(milliseconds: 400);

/// Gap between flip tiles, in both directions.
const double _gridGap = 6;

/// Screen 3: your picks against LedgerShield's picks, the 20-tile outcome
/// flip, the score and the one disagreement worth talking about.
class RevealScreen extends StatefulWidget {
  const RevealScreen({super.key});

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  List<CurvedAnimation> _tileAnimations = const [];
  Timer? _startTimer;
  bool _configured = false;
  bool _flipsDone = false;

  // What the screen shows is captured once, on the first dependency pass.
  // Play again starts a new session while this screen is still fading out
  // under the AnimatedSwitcher, and building from live controller state
  // would reshuffle the tiles and empty the picks mid-fade. Only the button
  // callbacks stay bound to the controller.
  late final GameController _controller;
  List<PoItem> _session = const [];
  Set<String> _yourIds = const {};
  Set<String> _modelIds = const {};
  List<PoItem> _yourPicks = const [];
  List<PoItem> _modelPicks = const [];
  String _headline = '';
  Disagreement? _disagreement;
  int _k = 0;
  int _yourCaught = 0;
  int _modelCaught = 0;
  double _yourExposure = 0;
  double _modelExposure = 0;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this)..addStatusListener(_onFlipStatus);
  }

  void _onFlipStatus(AnimationStatus status) {
    final done = status == AnimationStatus.completed;
    if (done != _flipsDone && mounted) {
      setState(() => _flipsDone = done);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion comes from MediaQuery, so the flip is configured here on
    // the first dependency pass rather than in initState. Later passes
    // (theme toggle, controller notifications) must not restart it.
    if (_configured) return;
    _configured = true;

    _controller = GameScope.of(context);
    _session = _controller.session;
    _yourPicks = _controller.yourPicks;
    _modelPicks = _controller.modelPicks;
    _yourIds = {for (final item in _yourPicks) item.id};
    _modelIds = {for (final item in _modelPicks) item.id};
    _headline = _controller.headline;
    _disagreement = _controller.biggestDisagreement;
    _k = _controller.k;
    _yourCaught = _controller.yourCaught;
    _modelCaught = _controller.modelCaught;
    _yourExposure = _controller.yourExposureProtected;
    _modelExposure = _controller.modelExposureProtected;

    final count = _session.length;
    final int totalMs =
        flipStagger.inMilliseconds * max<int>(count - 1, 0) +
        flipEach.inMilliseconds;
    _flip.duration = Duration(milliseconds: totalMs);
    _tileAnimations = List.generate(count, (i) {
      final start = flipStagger.inMilliseconds * i;
      final end = start + flipEach.inMilliseconds;
      return CurvedAnimation(
        parent: _flip,
        curve: Interval(
          start / totalMs,
          end / totalMs,
          curve: Curves.easeInOutCubic,
        ),
      );
    });

    if (reduceMotion(context)) {
      _flip.value = 1.0;
      _flipsDone = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startTimer = Timer(_flipStartDelay, () {
        if (mounted) _flip.forward();
      });
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    for (final a in _tileAnimations) {
      a.dispose();
    }
    _flip.removeStatusListener(_onFlipStatus);
    _flip.dispose();
    super.dispose();
  }

  /// The widest column count in 4, 3, 2 whose tiles hold both faces at the
  /// current text scale: the back face's outcome word and "You + LS" marker
  /// (6 px stripe plus 4 px padding either side) and the front face's mono
  /// vendor (6 px padding either side plus the 1 px border).
  int _columnsFor(BuildContext context, double width) {
    final caption = Theme.of(context).textTheme.bodySmall!;
    final word = measureText(
      context,
      Copy.exception,
      caption.copyWith(fontWeight: FontWeight.w600),
    ).width;
    final marker = measureText(
      context,
      [Copy.markerYou, Copy.markerModel].join(' + '),
      caption,
    ).width;
    var vendor = 0.0;
    for (final item in _session) {
      vendor = max(
        vendor,
        measureText(context, item.vendor, caption.merge(monoStyle)).width,
      );
    }
    final tileMin = max(max(word, marker) + 6 + 8, vendor + 12 + 2);
    for (final n in [4, 3]) {
      final tile = (width - (n - 1) * _gridGap) / n;
      if (tile >= tileMin) return n;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final session = _session;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnimatedOpacity(
              opacity: _flipsDone ? 1 : 0,
              duration: motionOr(context, const Duration(milliseconds: 300)),
              // The node enters the semantics tree when the flips complete
              // (or on the first frame under reduced motion), and the live
              // region announces it to a screen reader either way.
              child: Semantics(
                liveRegion: true,
                child: Text(_headline, style: text.headlineMedium),
              ),
            ),
            const SizedBox(height: 20),
            _PicksRow(yourPicks: _yourPicks, modelPicks: _modelPicks, k: _k),
            const SizedBox(height: 20),
            Text(Copy.whatActuallyHappened, style: text.bodySmall),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                crossAxisCount: _columnsFor(context, constraints.maxWidth),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: _gridGap,
                crossAxisSpacing: _gridGap,
                childAspectRatio: 1.0,
                children: [
                  for (var i = 0; i < session.length; i++)
                    FlipTile(
                      key: ValueKey(session[i].id),
                      animation: i < _tileAnimations.length
                          ? _tileAnimations[i]
                          : const AlwaysStoppedAnimation(1.0),
                      item: session[i],
                      yourPick: _yourIds.contains(session[i].id),
                      modelPick: _modelIds.contains(session[i].id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ScoreRow(
              yourCount: _yourPicks.length,
              yourCaught: _yourCaught,
              yourExposure: _yourExposure,
              k: _k,
              modelCaught: _modelCaught,
              modelExposure: _modelExposure,
            ),
            const SizedBox(height: 20),
            _DisagreementCard(disagreement: _disagreement),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _controller.showProof,
                      child: const Text(Copy.seeProof),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.tonal(
                      onPressed: _controller.playAgain,
                      child: const Text(Copy.playAgain),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => pushAuditLog(context),
              child: const Text(Copy.auditLog),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two columns: the player's holds and the model's top k, one mini row each.
class _PicksRow extends StatelessWidget {
  const _PicksRow({
    required this.yourPicks,
    required this.modelPicks,
    required this.k,
  });

  final List<PoItem> yourPicks;
  final List<PoItem> modelPicks;
  final int k;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PicksColumn(
            title: Copy.yourPicksTitle(yourPicks.length),
            picks: yourPicks,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PicksColumn(
            title: Copy.modelPicksTitle(k),
            picks: modelPicks,
          ),
        ),
      ],
    );
  }
}

class _PicksColumn extends StatelessWidget {
  const _PicksColumn({required this.title, required this.picks});

  final String title;
  final List<PoItem> picks;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleLarge),
        const SizedBox(height: 8),
        for (final item in picks) ...[
          _MiniRow(item: item),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// One line per pick: the vendor (the same label the flip-tile front shows,
/// so the eye can match the two), the exposure, and the outcome. The full id
/// stays on the Disagreement card and in the Audit log.
class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.item});

  final PoItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final caption = Theme.of(context).textTheme.bodySmall!;
    // Two lines per pick: the full id on top, then the exposure and the
    // outcome word. One line cannot hold all three in a half-width column
    // without wrapping the outcome word under its icon.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatId(item.id),
            semanticsLabel: item.id,
            style: caption.merge(monoStyle).copyWith(color: c.ink),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatUnits(item.exposureUnits),
                style: caption.merge(monoStyle),
              ),
              const SizedBox(width: 8),
              Expanded(child: _OutcomeLine(item: item)),
            ],
          ),
        ],
      ),
    );
  }
}

/// A warning icon plus "Exception" or a check plus "Fine", in ink. The icon
/// colour and shape agree with the flip-tile stripe for that outcome, and
/// the icon rides inside the text run so the line baseline-aligns with the
/// mono numbers beside it.
class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({required this.item});

  final PoItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final caption = Theme.of(context).textTheme.bodySmall!;
    final isException = item.outcome.exceptionReachedClearance;
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: ExcludeSemantics(
              child: Icon(
                isException ? Icons.error_outline : Icons.check,
                size: 16,
                color: isException ? c.riskHigh : c.accent,
              ),
            ),
          ),
          const TextSpan(text: ' '),
          TextSpan(text: isException ? Copy.exception : Copy.fine),
        ],
      ),
      style: caption.copyWith(color: c.ink),
    );
  }
}

/// Caught count and protected exposure for both pickers. The player's "of N"
/// is the real hold count; the model's is k.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.yourCount,
    required this.yourCaught,
    required this.yourExposure,
    required this.k,
    required this.modelCaught,
    required this.modelExposure,
  });

  final int yourCount;
  final int yourCaught;
  final double yourExposure;
  final int k;
  final int modelCaught;
  final double modelExposure;

  @override
  Widget build(BuildContext context) {
    // Both cards share the taller height when one caption wraps further.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ScoreColumn(
              title: Copy.yourPicksTitle(yourCount),
              caught: yourCaught,
              of: yourCount,
              exposure: yourExposure,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ScoreColumn(
              title: Copy.modelPicksTitle(k),
              caught: modelCaught,
              of: k,
              exposure: modelExposure,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({
    required this.title,
    required this.caught,
    required this.of,
    required this.exposure,
  });

  final String title;
  final int caught;
  final int of;
  final double exposure;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: lsCard(context, radius: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.bodySmall),
            const SizedBox(height: 6),
            Text(Copy.exceptionsCaught(caught, of), style: text.bodyLarge),
            const SizedBox(height: 4),
            Text(
              Copy.protectedExposure(formatUnits(exposure)),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The one card where the two pickers split, or the "same five" sentence.
class _DisagreementCard extends StatelessWidget {
  const _DisagreementCard({required this.disagreement});

  final Disagreement? disagreement;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final text = Theme.of(context).textTheme;
    final d = disagreement;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lsCard(context, borderColor: c.riskMid, borderWidth: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Copy.disagreementTitle, style: text.titleLarge),
          const SizedBox(height: 8),
          if (d == null)
            Text(Copy.samePicks, style: text.bodyLarge)
          else ...[
            Text(switch (d.side) {
              DisagreementSide.modelOnly => Copy.sideModelOnly,
              DisagreementSide.playerOnly => Copy.sidePlayerOnly,
            }, style: text.bodySmall),
            const SizedBox(height: 8),
            Text(d.item.id, style: text.bodyLarge!.merge(monoStyle)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatUnits(d.item.exposureUnits),
                  style: text.bodyLarge!.merge(monoStyle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(Copy.exposureCaption, style: text.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _OutcomeLine(item: d.item),
            const SizedBox(height: 8),
            Text(d.why, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}
