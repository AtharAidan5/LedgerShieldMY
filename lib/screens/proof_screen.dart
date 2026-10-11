import 'package:flutter/material.dart';

import '../copy.dart';
import '../data/models.dart';
import '../game/game_scope.dart';
import '../theme/ls_colors.dart';
import '../theme/ls_theme.dart';
import '../util/format.dart';
import '../widgets/placeholder_badge.dart';
import '../widgets/policy_bar.dart';
import 'audit_screen.dart';

/// Screen 4, the Proof receipt. One scrolling card with the held-out numbers,
/// then the small print and the buttons fixed below it so the disclaimer is
/// visible at any viewport height or font scale.
class ProofScreen extends StatefulWidget {
  const ProofScreen({super.key});

  @override
  State<ProofScreen> createState() => _ProofScreenState();
}

class _ProofScreenState extends State<ProofScreen> {
  bool _vendorHeldout = false;

  @override
  Widget build(BuildContext context) {
    final controller = GameScope.of(context);
    final proof = controller.proof;
    final c = context.ls;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Center(
                  child: proof == null
                      ? const SizedBox.shrink()
                      : _ReceiptCard(
                          proof: proof,
                          vendorHeldout: _vendorHeldout,
                          onVendorHeldoutChanged: (v) =>
                              setState(() => _vendorHeldout = v),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                Copy.smallPrint,
                style: text.bodySmall?.copyWith(color: c.inkMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.tonal(
                        onPressed: controller.showReveal,
                        child: const Text(Copy.backToReveal),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: controller.playAgain,
                        child: const Text(Copy.playAgain),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.proof,
    required this.vendorHeldout,
    required this.onVendorHeldoutChanged,
  });

  final ProofData proof;
  final bool vendorHeldout;
  final ValueChanged<bool> onVendorHeldoutChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final text = Theme.of(context).textTheme;
    final placeholder = proof.isPlaceholder;
    // The banner at the top of the receipt is the one placeholder marker. A
    // badge on every row as well would outweigh the numbers it qualifies, so
    // the rows below carry none.
    final precision = vendorHeldout
        ? proof.vendorHeldout.precisionAtK
        : proof.precisionAtK;
    final exposureRecall = vendorHeldout
        ? proof.vendorHeldout.exposureRecallAtK
        : proof.exposureRecallAtK;

    return Container(
      decoration: lsCard(context),
      child: CustomPaint(
        painter: _ReceiptEdgePainter(color: c.line),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (placeholder) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PlaceholderBadge(text: Copy.placeholderBanner),
                ),
                const SizedBox(height: 16),
              ],
              Text(Copy.proofTitle, style: text.headlineMedium),
              const SizedBox(height: 4),
              Text(Copy.kPerDay(proof.kPerDay), style: text.bodySmall),
              const SizedBox(height: 20),
              Text(
                vendorHeldout
                    ? Copy.proofSectionHeldout
                    : Copy.proofSectionShare,
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final policy in proof.policies) ...[
                PolicyBar(
                  label: policy.name,
                  value: policy.recallAtK,
                  highlighted: _isLedgerShield(policy),
                ),
                const SizedBox(height: 16),
              ],
              // The three numbers sit one per line, like receipt items.
              _StatTile(
                label: Copy.statPrecision,
                value: formatProb(precision),
              ),
              const SizedBox(height: 8),
              _StatTile(
                label: Copy.statExposureRecall,
                value: formatProb(exposureRecall),
              ),
              const SizedBox(height: 8),
              _StatTile(
                label: Copy.statMedianDays,
                value: vendorHeldout
                    ? Copy.notAvailableForVariant
                    : formatUnits(proof.medianDaysWarning),
                // The held-out variant has no median figure, so the tile
                // shows a caption instead of a number.
                mono: !vendorHeldout,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: const Text(Copy.chipVendorHeldout),
                  selected: vendorHeldout,
                  onSelected: onVendorHeldoutChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isLedgerShield(Policy p) =>
      p.name.toLowerCase().contains('ledgershield');
}

/// One receipt line: the value in mono, then its label, baseline-aligned
/// and spoken as "label, value" so the number is heard with its meaning.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.mono = true,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.ls;
    final text = Theme.of(context).textTheme;
    final valueStyle = mono
        ? text.bodyLarge?.merge(monoStyle).copyWith(color: c.ink)
        : text.bodySmall?.copyWith(color: c.ink);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: Copy.labelledValue(label, value),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // A fixed minimum keeps the labels in one column without leaving
            // a hole after a four-character value.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: Text(value, style: valueStyle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: text.bodySmall)),
          ],
        ),
      ),
    );
  }
}

/// Dashed lines just inside the top and bottom edges give the card the look
/// of a till receipt without changing its rounded outline.
class _ReceiptEdgePainter extends CustomPainter {
  const _ReceiptEdgePainter({required this.color});

  final Color color;

  static const double _inset = 10;
  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (final y in [_inset, size.height - _inset]) {
      var x = 20.0;
      final end = size.width - 20.0;
      while (x < end) {
        final x2 = (x + _dash).clamp(x, end);
        canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
        x += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_ReceiptEdgePainter oldDelegate) =>
      oldDelegate.color != color;
}
