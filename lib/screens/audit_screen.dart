import 'package:flutter/material.dart';

import '../copy.dart';
import '../game/decision.dart';
import '../game/game_scope.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../theme/motion.dart';
import '../util/format.dart';

/// Pushes the Audit log as a fading route. Flutter does not shorten route
/// transitions on its own under reduced motion, so both durations take
/// [motionOr].
Future<void> pushAuditLog(BuildContext context) {
  final duration = motionOr(context, switcher);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => const AuditScreen(),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

String _decisionLabel(Decision d) => switch (d) {
  Decision.hold => Copy.decisionHeld,
  Decision.release => Copy.decisionReleased,
  Decision.autoRelease => Copy.decisionAutoReleased,
  Decision.escalate => Copy.decisionEscalated,
};

String _sourceLabel(DecisionSource s) => switch (s) {
  DecisionSource.swipe => Copy.sourceSwipe,
  DecisionSource.button => Copy.sourceButton,
  DecisionSource.sheet => Copy.sourceSheet,
  DecisionSource.auto => Copy.sourceAuto,
};

/// Screen 5: one row per decision, including auto-releases.
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GameScope.of(context);
    final entries = controller.auditEntries;
    final text = Theme.of(context).textTheme;
    final c = context.ls;
    return Scaffold(
      appBar: AppBar(title: const Text(Copy.auditTitle)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(Copy.auditHeader, style: text.bodySmall),
            ),
            Divider(height: 1, color: c.line),
            Expanded(
              child: entries.isEmpty
                  ? Center(child: Text(Copy.auditEmpty, style: text.bodySmall))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.line),
                      itemBuilder: (context, i) => _AuditRow(entry: entries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One decision. The five pieces of text merge into a single spoken row, and
/// the id wraps onto a second line at large text rather than being cut.
class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.ls;
    final mono = text.bodySmall!.merge(monoStyle);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(formatTime(entry.at), style: mono),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    formatId(entry.itemId),
                    semanticsLabel: entry.itemId,
                    style: mono.copyWith(color: c.ink),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(_decisionLabel(entry.decision), style: text.bodyLarge),
                const SizedBox(width: 8),
                Text(_sourceLabel(entry.source), style: text.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(entry.reason, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
